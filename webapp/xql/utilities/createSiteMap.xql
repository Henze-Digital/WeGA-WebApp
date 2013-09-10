xquery version "3.0" encoding "UTF-8";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace mei="http://www.music-encoding.org/ns/mei";
declare namespace exist="http://exist.sourceforge.net/NS/exist";
declare namespace request="http://exist-db.org/xquery/request";
declare namespace xmldb="http://exist-db.org/xquery/xmldb";
declare namespace util="http://exist-db.org/xquery/util";
declare namespace compression="http://exist-db.org/xquery/compression";
declare namespace response="http://exist-db.org/xquery/response";
declare namespace sm="http://exist-db.org/xquery/securitymanager";
import module namespace wega = "http://xquery.weber-gesamtausgabe.de/webapp/xql/modules/wega" at "xmldb:exist:///db/webapp/xql/modules/wega.xqm";
import module namespace functx="http://www.functx.com" at "xmldb:exist:///db/webapp/xql/modules/functx.xqm";
import module namespace facets="http://xquery.weber-gesamtausgabe.de/webapp/xql/modules/facets" at "xmldb:exist:///db/webapp/xql/modules/facets.xqm";

declare option exist:serialize "method=xml media-type=application/xml indent=yes omit-xml-declaration=no encoding=utf-8";

declare variable $local:languages := ('en', 'de');
declare variable $local:defaultCompression := 'gz'; (: gz or zip :)
declare variable $local:standardEntries := ('index', 'search', 'help', 'projectDescription', 'contact', 'editorialGuidelines'(:, 'publications':), 'bibliography');
declare variable $local:databaseEntries := ('persons', 'letters', 'writings', 'diaries', (:'works',:) 'news'(:, 'biblio':));

declare function local:getUrlList($type as xs:string, $lang as xs:string) as element(url)* {
    for $x in facets:getOrCreateColl($type, 'indices', true())
    let $lastmod := wega:getLastModifyDateOfDocument(document-uri($x))
    let $loc := wega:createLinkToDoc($x, $lang) 
    return 
        <url xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">{
            element loc {$loc},
            if(exists($lastmod)) then element lastmod {$lastmod}
            else ()
        }</url>
};

declare function local:createSitemap($lang as xs:string) as element(urlset) {
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
        {for $i in $local:standardEntries return 
            <url><loc>{string-join((wega:getOption('baseHref'), $lang, replace(wega:getLanguageString($i, $lang), '\s', '_')), '/')}</loc></url>
        }
        {
        (:for $k in $local:databaseEntries return local:getUrlList($k, $lang):)
        ()
        }
    </urlset>
};

declare function local:createSitemapIndex($fileNames as xs:string*) as element(sitemapindex) {
    <sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
        {for $fileName in $fileNames
        return <sitemap><loc>{string-join((wega:getOption('baseHref'), wega:getOption('html_sitemapDir'), $fileName), '/')}</loc></sitemap>
        }
    </sitemapindex>
};

declare function local:getSetSitemap($fileName as xs:string) as xs:base64Binary {
    let $sitemapLang := substring-after(substring-before($fileName, '.'), '_')
    let $folderName := wega:getOption('sitemapDir')
    let $currentDateTimeOfFile := 
        if(xmldb:collection-available($folderName)) then xmldb:last-modified($folderName, $fileName) 
        else local:createSitemapCollection($folderName) 
    let $updateNecessary := typeswitch($currentDateTimeOfFile) 
	   case xs:dateTime return wega:eXistDbWasUpdatedAfterwards($currentDateTimeOfFile) or not(util:binary-doc-available(string-join(($folderName, $fileName), '/')))
	   default return true()
    return 
        if($updateNecessary) then (
            let $newSitemap := local:createSitemap($sitemapLang)
            let $logMessage := concat('Creating sitemap: ', $fileName)
            let $logToFile := wega:logToFile('info', $logMessage)
            return 
                if(exists($newSitemap)) then (
                    let $compression := functx:substring-after-last($fileName, '.')
                    let $compressedData := local:compressXML($newSitemap, functx:substring-before-last($fileName, '.'), $compression)
                    let $storedData := xmldb:store($folderName, $fileName, $compressedData, local:getMimeType($compression))
                    return util:binary-doc($storedData)
                )
                else ()
        )
        else util:binary-doc(string-join(($folderName, $fileName), '/'))
};

declare function local:getMimeType($compression as xs:string) as xs:string? {
    if($compression eq 'zip') then 'application/zip' 
    else if($compression eq 'gz') then 'application/gzip'
    else ()
};

declare function local:createSitemapCollection($path as xs:string) as empty() {
    let $createCollection := 
        try { xmldb:create-collection(functx:substring-before-last($path, '/'), functx:substring-after-last($path, '/')) }
        catch * {wega:logToFile('error', 'failed to create sitemap collection')}
    let $setPermissions :=
        if(xmldb:collection-available($path)) then (
            sm:chown(xs:anyURI($path), 'guest'),
            sm:chgrp(xs:anyURI($path), 'guest'),
            sm:chmod(xs:anyURI($path), sm:octal-to-mode('755'))
        )
        else ()
    return ()
};

declare function local:compressXML($xml as element(), $fileName as xs:string, $compression as xs:string) as xs:base64Binary? {
    if($compression eq 'zip') then compression:zip(<entry name="{$fileName}" type="xml" method="deflate">{$xml}</entry>, false())
    else if($compression eq 'gz') then (
        let $serializationParameters := ('method=xml', 'media-type=application/xml', 'indent=no', 'omit-xml-declaration=no', 'encoding=utf-8')
        return compression:gzip(util:string-to-binary(util:serialize($xml, $serializationParameters)))
    )
    else ()
};

let $appLang := request:get-parameter('lang', 'de')
let $resource := request:get-parameter('resource', '')
let $host := request:get-parameter('host', wega:getOption('baseHref'))
let $compression := if(ends-with($resource, 'zip')) then 'zip' else $local:defaultCompression
let $properFileNames := for $lang in $local:languages return concat('sitemap_', $lang, '.xml.', $compression)

return
    if($properFileNames = $resource) then response:stream-binary(local:getSetSitemap($resource), local:getMimeType($compression), $resource)
    else local:createSitemapIndex($properFileNames)
