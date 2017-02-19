xquery version "3.0" encoding "UTF-8";

(:~
 : XQuery functions for the main controller
 :)
module namespace controller="http://xquery.weber-gesamtausgabe.de/modules/controller";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace mei="http://www.music-encoding.org/ns/mei";
declare namespace exist="http://exist.sourceforge.net/NS/exist";
declare namespace xmldb="http://exist-db.org/xquery/xmldb";
declare namespace request="http://exist-db.org/xquery/request";
declare namespace xhtml="http://www.w3.org/1999/xhtml";

import module namespace config="http://xquery.weber-gesamtausgabe.de/modules/config" at "config.xqm";
import module namespace core="http://xquery.weber-gesamtausgabe.de/modules/core" at "core.xqm";
import module namespace query="http://xquery.weber-gesamtausgabe.de/modules/query" at "query.xqm";
import module namespace lang="http://xquery.weber-gesamtausgabe.de/modules/lang" at "lang.xqm";
import module namespace str="http://xquery.weber-gesamtausgabe.de/modules/str" at "str.xqm";
import module namespace wdt="http://xquery.weber-gesamtausgabe.de/modules/wdt" at "wdt.xqm";
import module namespace functx="http://www.functx.com";

(:~
 : HTML output. Forwards to a given template and takes care of ETag caching
 :
 : @param $html-template the HTML template for processing by the templating module. The path must be given relative to the app root collection
 : @param $exist-vars the keys of this map object will get passed through to the following modules by sending them as request attributes
~:)
declare function controller:forward-html($html-template as xs:string, $exist-vars as map()*) as element(exist:dispatch) {
    let $etag := controller:etag($exist-vars('exist:path'))
    let $modified := not(request:get-header('If-None-Match') = $etag)
    return (
        <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
            <forward url="{str:join-path-elements((map:get($exist-vars, 'exist:controller'), $html-template))}"/>
            <view>
                <forward url="{str:join-path-elements((map:get($exist-vars, 'exist:controller'), 'modules/view-html.xql'))}" method="get">
                	{
                	for $var in map:keys($exist-vars) 
                	return
                		<set-attribute name="{$var}" value="{$exist-vars($var)}"/>
                	}
                    <!-- Need to provoke 304 error in view-html.xql if unmodified -->
                    <set-attribute name="modified" value="{$modified cast as xs:string}"/>
                </forward>
                {if($modified) then 
                <forward url="{str:join-path-elements((map:get($exist-vars, 'exist:controller'), 'modules/view-tidy.xql'))}">
                    <set-attribute name="lang" value="{$exist-vars('lang')}"/>
                </forward>
                else ()}
            </view>
            {if($modified) then
            <error-handler>
                <forward url="{str:join-path-elements((map:get($exist-vars, 'exist:controller'), '/templates/error-page.html'))}" method="get">
                	{
                	for $var in map:keys($exist-vars) 
                	return
                		<set-attribute name="{$var}" value="{$exist-vars($var)}"/>
                	}
                </forward>
                <forward url="{str:join-path-elements((map:get($exist-vars, 'exist:controller'), '/modules/view-html.xql'))}">
                	{
                	for $var in map:keys($exist-vars) 
                	return
                		<set-attribute name="{$var}" value="{$exist-vars($var)}"/>
                	}
                </forward>
            </error-handler>
            else ()}
        </dispatch>,
        response:set-header('Cache-Control', 'max-age=120,public'),
        response:set-header('ETag', $etag)
    )
};

declare function controller:forward-xml($exist-vars as map()*) as element(exist:dispatch) {
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{map:get($exist-vars, 'exist:controller') || '/modules/view-xml.xql'}">
            <!--<set-attribute name="resource" value="{$exist-vars('docID')}"/> -->
            {
            for $var in map:keys($exist-vars) 
            return
                <set-attribute name="{$var}" value="{$exist-vars($var)}"/>
            }
        </forward>
    </dispatch>
};

(:~
 : Redirect to given (absolute) path
 : 
 : @author Peter Stadler
 : @param $path the path to redirect to
 : @return exist:dispatch element for controller.xql
 :)
declare function controller:redirect-absolute($path as xs:string) as element(exist:dispatch) {
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="{core:link-to-current-app($path)}"/>
    </dispatch>
};


declare function controller:dispatch($exist-vars as map(*)) as element(exist:dispatch) {
    let $media-type := controller:media-type($exist-vars)
    let $docID := functx:substring-before-if-contains($exist-vars('exist:resource'), '.')
    let $updated-exist-vars := 
        map:new((
            $exist-vars, 
            map:entry('docID', $docID),
            map:entry('docType', config:get-doctype-by-id($docID)),
            map:entry('media-type', $media-type)
        ))
    let $doc := core:doc($docID)
    let $path := controller:encode-path-segments-for-uri(controller:path-to-resource($doc, $exist-vars('lang')))
(:    let $log := util:log-system-out($exist-vars('exist:path')):)
(:    let $log := util:log-system-out($path):)
    return 
        if($media-type and $exist-vars('exist:path') eq $path || '.' || $media-type) then controller:forward-document($updated-exist-vars)
        else if($media-type and $path) then controller:redirect-absolute('/' || $exist-vars?prefix || '/' || $exist-vars?controller || $path || '.' || $media-type)
        else controller:error($exist-vars, 404)
};

(:~
 : Dispatch pages for tab "Indices"
 :)
declare function controller:dispatch-register($exist-vars as map(*)) as element(exist:dispatch) {
    let $indexDocTypes := for $func in wdt:members('indices') return $func(())('name') (: = all supported docTypes :)
    let $docType := 
        if($exist-vars('exist:resource')) then lang:reverse-language-string-lookup(replace(xmldb:decode($exist-vars('exist:resource')), '_', ' '), $exist-vars('lang'))[. = ($indexDocTypes, 'indices')]
        else 'indices'
    let $path := controller:encode-path-segments-for-uri(controller:path-to-register($docType, $exist-vars('lang')))
    let $updated-exist-vars := 
        map:new((
            $exist-vars, 
            map:entry('docID', 'indices'),
            map:entry('docType', $docType)
        ))
    return 
        if($exist-vars('exist:path') eq $path) then controller:forward-html('/templates/register.html', $updated-exist-vars)
        else controller:error($exist-vars, 404)
};

(:~
 : Dispatch pages for tab "Project"
 :)
declare function controller:dispatch-project($exist-vars as map(*)) as element(exist:dispatch) {
    let $project-nav := doc(concat($config:app-root, '/templates/page.html'))//(xhtml:li[@id='project-nav']//xhtml:a | xhtml:ul[@class='footerNav']//xhtml:a) 
    let $request := request:get-uri()
    let $a := distinct-values($project-nav/@href[controller:encode-path-segments-for-uri(controller:resolve-link(.,$exist-vars)) = $request]/parent::*)
    return
        switch($a)
        case 'bibliography' case 'news' return controller:dispatch-register($exist-vars)
        (: Need to inject the corresponding IDs of special pages here :)
        case 'projectDescription' return controller:forward-html('/templates/var.html', map:new(($exist-vars, map:entry('docID', 'A070006'), map:entry('docType', 'var')))) 
        case 'editorialGuidelines-text'  return controller:forward-html('/templates/var.html', map:new(($exist-vars, map:entry('docID', 'A070001'), map:entry('docType', 'var'))))
        case 'editorialGuidelines-music'  return controller:forward-html('/templates/var.html', map:new(($exist-vars, map:entry('docID', 'A070010'), map:entry('docType', 'var'))))
        case 'contact' return controller:forward-html('/templates/var.html', map:new(($exist-vars, map:entry('docID', 'A070009'), map:entry('docType', 'var'))))
        case 'about' return controller:forward-html('/templates/var.html', map:new(($exist-vars, map:entry('docID', 'A070002'), map:entry('docType', 'var'))))
        case 'volContents' return controller:forward-html('/templates/var.html', map:new(($exist-vars, map:entry('docID', 'A070011'), map:entry('docType', 'var'))))
        case 'credits' return controller:forward-html('/templates/var.html', map:new(($exist-vars, map:entry('docID', 'A070013'), map:entry('docType', 'var'))))
        default return controller:error($exist-vars, 404)
};

(:~
 : Dispatch pages for tab "Help"
 :)
declare function controller:dispatch-help($exist-vars as map(*)) as element(exist:dispatch) {
    let $help-nav := doc(concat($config:app-root, '/templates/page.html'))//(xhtml:li[@id='help-nav']//xhtml:a | xhtml:ul[@class='footerNav']//xhtml:a) 
    let $request := request:get-uri()
    let $a := distinct-values($help-nav/@href[controller:encode-path-segments-for-uri(controller:resolve-link(.,$exist-vars)) = $request]/parent::*)
    return
        switch($a)
        (: Need to inject the corresponding IDs of special pages here :)
        case 'faq' return controller:forward-html('/templates/var.html', map:new(($exist-vars, map:entry('docID', 'A070004'), map:entry('docType', 'var')))) 
        case 'apiDocumentation'  return controller:forward-html('/templates/var.html', map:new(($exist-vars, map:entry('docID', 'A070012'), map:entry('docType', 'var'))))
        default return controller:error($exist-vars, 404)
};

(:~
 : Dispatch pages under "editorial guidelines text"
~:)
declare function controller:dispatch-editorialGuidelines-text($exist-vars as map(*)) as element(exist:dispatch) {
	(: Needs to be fleshed out … :)
	let $media-type := controller:media-type($exist-vars)
    let $specID := functx:substring-before-if-contains($exist-vars('exist:resource'), '.')
	let $specIdents := collection($config:app-root || '/guidelines/compiledODD')//(tei:elementSpec, tei:classSpec, tei:macroSpec, tei:dataSpec)/@ident
	let $schemaIdents := collection($config:app-root || '/guidelines/compiledODD')//tei:schemaSpec/@ident
	let $pathTokens := tokenize(substring-after($exist-vars('exist:path'), $exist-vars?controller), '/')[.]
	(:let $path := core:link-to-current-app(str:join-path-elements(lang:get-language-string('editorialGuidelines-text', $lang), )):)
(:    let $log := util:log-system-out($exist-vars('exist:path')):)
(:    let $log := util:log-system-out(count( $specIdents)):)
    return 
        if(
        	$media-type = 'html' 
        	and $pathTokens[4] = $schemaIdents 
        	and $specID = $specIdents
        	and $pathTokens[5] = $specID || '.' || $media-type  
        	) then controller:forward-html('/templates/specs.html', map:new(($exist-vars, map:entry('specID', $specID), map:entry('schemaID', $pathTokens[4]))))
		else if (
			$media-type = 'xml' 
        	and $pathTokens[4] = $schemaIdents 
        	and $specID = $specIdents
        	and $pathTokens[5] = $specID || '.' || $media-type
			) then controller:forward-xml(map:new(($exist-vars, map {'specID' := $specID, 'schemaID' := $pathTokens[4]} )))
		else if(
			$media-type 
			and $specID = $specIdents 
			and $pathTokens[4] = $schemaIdents
			and $pathTokens[5] = $specID
		) then controller:redirect-absolute('/' || $exist-vars?prefix || '/' || $exist-vars?controller || $exist-vars?path || '.' || $media-type)
        else controller:error($exist-vars, 404)
};

declare function controller:error($exist-vars as map(*), $errorCode as xs:int) as element(exist:dispatch) {
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
    	<forward url="{str:join-path-elements((map:get($exist-vars, 'exist:controller'), 'templates/error-page.html'))}"/>
    	<view>
         <forward url="{str:join-path-elements((map:get($exist-vars, 'exist:controller'), '/modules/view-html.xql'))}">
         	{
         		for $var in map:keys($exist-vars) 
	            return
	            	<set-attribute name="{$var}" value="{$exist-vars($var)}"/>
            }
             <set-attribute name="docType" value="error"/>
             <set-attribute name="modified" value="true"/>
             <cache-control cache="yes"/>
         </forward>
         <forward url="{str:join-path-elements((map:get($exist-vars, 'exist:controller'), 'modules/view-tidy.xql'))}">
            {
            for $var in map:keys($exist-vars) 
            return
                <set-attribute name="{$var}" value="{$exist-vars($var)}"/>
            }
         </forward>
     </view>
  </dispatch>,
   response:set-status-code($errorCode)
};


(:~
 : Split URI into path segments and encode those for URI if necessary
 : 
 : @author Peter Stadler
 : @param $uri
 :)
declare function controller:encode-path-segments-for-uri($uri-string as xs:string?) as xs:string? {
    typeswitch($uri-string)
    case xs:string return 
        if(matches($uri-string, '^[a-zA-Z0-9/]+$')) then $uri-string
        else str:join-path-elements(tokenize($uri-string, '/') ! encode-for-uri(.))
    default return ()
};

declare function controller:path-to-resource($doc as document-node()?, $lang as xs:string) as xs:string? {
    let $docID := $doc/*/@xml:id
    let $docType := config:get-doctype-by-id($docID) (: Die originale Darstellung der doctypes, also 'persons', 'letters' etc:)
    let $displayName := (: Die Darstellung als URL, also 'Korrespondenz', 'Tagebücher' etc. :)
        try {
            if(config:is-letter($docID)) then lang:get-language-string('correspondence', $lang) (: Ausnahme für Briefe=Korrespondenz:)
            else if(config:is-weberStudies($doc)) then lang:get-language-string('weberStudies', $lang)
            else if($docType = 'var') then 'var'
            else lang:get-language-string($docType, $lang)
        }
        catch * {()}
    let $authorID := 
        try {
            query:get-authorID($doc)
        }
        catch * {()}
    return 
        if($docType = ('persons', 'orgs')) then str:join-path-elements(('/', $lang, $docID))
        else if($docType = 'var') then str:join-path-elements(('/', $lang, lang:get-language-string('project', $lang), $docID))
        else if($authorID and $displayName) then str:join-path-elements(('/', $lang, $authorID, $displayName, $docID))
        else core:logToFile('error', 'controller:path-to-resource(): could not create path for ' || $docID)
};

(:~
 : Indices can be under "Register (Indices)" or "Projekt (Project)" 
~:)
declare function controller:path-to-register($docType as xs:string, $lang as xs:string) as xs:string? {
    if($docType = ('letters', 'diaries', 'personsPlus', 'writings', 'works', 'thematicCommentaries', 'documents')) then str:join-path-elements(('/', $lang, lang:get-language-string('indices', $lang), lang:get-language-string($docType, $lang)))
    else if($docType = ('biblio', 'news')) then str:join-path-elements(('/', $lang, lang:get-language-string('project', $lang), lang:get-language-string($docType, $lang)))
    else if($docType = 'indices') then str:join-path-elements(('/', $lang, lang:get-language-string('indices', $lang)))
    else if($docType = 'project') then str:join-path-elements(('/', $lang, lang:get-language-string('project', $lang)))
    else core:logToFile('error', 'controller:path-to-register(): could not create path for ' || $docType)
};

declare function controller:docType-url-for-author($author as document-node(), $docType as xs:string, $lang as xs:string) as xs:string {
    let $docType-path-segment := 
        switch($docType)
        case 'letters' return 'correspondence'
        default return $docType
    return
        core:link-to-current-app(str:join-path-elements((controller:path-to-resource($author, $lang), $docType-path-segment || '.html')))
};

(:
 : links can be encoded within the HTML with the prefix '$link'
 : these links are resolved here
 : 
 :)
declare function controller:resolve-link($link as xs:string, $exist-vars as map()) as xs:string? {
    let $tokens := 
        for $token in tokenize(substring-after($link, '$link/'), '/')
        let $has-suffix := contains($token, '.')
        return 
            if(matches($token, 'A[A-F0-9]{6}')) then $token
            else if(matches($token, 'dev|test-html')) then $token
            else if($has-suffix) then lang:get-language-string(substring-before($token, '.'), $exist-vars?lang) || '.' || substring-after($token, '.')
            else lang:get-language-string($token, $exist-vars?lang)
        (:return 
            if($translation) then replace($translation, '\s+', '_') 
            else $token:)
    return 
        core:link-to-current-app(str:join-path-elements(($exist-vars?lang, $tokens)), $exist-vars)
};

declare function controller:translate-URI($uri as xs:string,$sourceLang as xs:string, $targetLang as xs:string) as xs:string {
    let $langRegex := '/(' || string-join($config:valid-languages, '|') || ')/'
    let $tokens := tokenize(functx:substring-after-match($uri, $langRegex), '/')
    let $translated-tokens := 
        for $token in $tokens
        let $has-suffix := contains($token, '.')
        return
            if(matches($token, 'A\d{2}[0-9A-F]')) then $token
            else if($has-suffix) then lang:translate-language-string(replace(substring-before(xmldb:decode($token), '.'), '_', ' '), $sourceLang, $targetLang) || '.' || substring-after($token, '.')
            else lang:translate-language-string(replace(xmldb:decode($token), '_', ' '), $sourceLang, $targetLang)
    return
        core:link-to-current-app(str:join-path-elements(($targetLang,$translated-tokens)))
};

declare function controller:redirect-by-gnd($exist-vars as map(*)) as element(exist:dispatch) {
    let $doc := query:doc-by-gnd(functx:substring-before-if-contains($exist-vars('exist:resource'), '.'))
    let $media-type := controller:media-type($exist-vars)
    return
        if(exists($doc) and $media-type) then controller:redirect-absolute(controller:path-to-resource($doc, $exist-vars('lang')) || '.' || $media-type)
        else controller:error($exist-vars, 404)
};

declare function controller:lookup-url-mappings($exist-vars as map(*)) {
    let $lookup-table := doc($config:catalogues-collection-path || '/urlMappings.xml')
    let $mapping := $lookup-table//mapping[controller:encode-path-segments-for-uri(@from) = $exist-vars('exist:path')]
(:    let $log := util:log-system-out($exist-vars('exist:path')):)
    return
        if($mapping) then controller:redirect-absolute(controller:encode-path-segments-for-uri($mapping/normalize-space(@to)))
        (: zum debuggen rausgenommen um Fehler anzuzeigen:)
        else if($config:isDevelopment) then util:log-system-out('fail for: ' || $exist-vars('exist:path'))
        else controller:error($exist-vars, 404)
};

declare function controller:lookup-typo3-mappings($exist-vars as map(*)) {
    let $lookup-table := doc($config:catalogues-collection-path || '/typo3ContentMappings.xml')
    let $oldID := request:get-parameter('id', '')
    let $mapping := 
        if($oldID castable as xs:integer) then $lookup-table//entry[@oldID = $oldID]
        else ()
    return
        if($mapping) then controller:redirect-absolute(controller:encode-path-segments-for-uri(normalize-space($mapping)))
        else if($config:isDevelopment) then util:log-system-out('fail for: ' || $exist-vars('exist:path'))
        else controller:error($exist-vars, 404)
};

declare %private function controller:resource-id($exist-vars as map(*)) as xs:string? {
    let $regex := '^A\d{2}[0-9A-F]{4}\.' || string-join($config:valid-resource-suffixes, '|') || '$'
    return
        if(matches($exist-vars('exist:resource'), $regex)) then substring-before($exist-vars('exist:resource'), '.')
        else ()
};

(:~
 : Figure out the requested mime type for a resource by looking at its file extension and HTTP request headers.
 : The file extension gets precedence over HTTP headers; 
 : when no supported file extension nor HTTP headers are given, the empty sequence is returned.
 : 
 : @author Peter Stadler
 : @param $exist-vars a map containing various stuff, here we need the requested resource, i.e. $exist-vars('exist:resource')
 : @return a string {html|xml} or empty sequence
 :)
declare %private function controller:media-type($exist-vars as map(*)) as xs:string? {
    let $suffix := functx:substring-after-last($exist-vars('exist:resource'), '.')
    let $header := tokenize(request:get-header('Accept'), ',')
    return
        if($suffix and $suffix ne $exist-vars('exist:resource')) then controller:canonical-mime-type($suffix)
        else controller:canonical-mime-type($header)
};

(:~
 : Helper function for controller:media-type()
 : Recursively loop through a sequence of strings and see whether some string matches a defined pattern. 
 : Return the first matching string.
 : 
 : @author Peter Stadler
 : @param $mime-type some string representation of a mime type, e.g. "xml" or "application/xml"
 : @return a string {html|xml} or empty sequence
 :)
declare %private function controller:canonical-mime-type($mime-type as xs:string*) as xs:string? {
    switch($mime-type[1])
    case 'html' case 'htm' return 'html'
    case 'xml' case 'tei' return 'xml'
    case 'text/html' case 'application/xhtml+xml' return 'html'
    case 'application/xml' case 'application/tei+xml' return 'xml'
    default return 
        if(count($mime-type) gt 1) then controller:canonical-mime-type(subsequence($mime-type, 2))
        else ()
};

declare %private function controller:forward-document($exist-vars as map(*)) as element(exist:dispatch) {
    switch($exist-vars('media-type'))
    case 'html' return
        switch($exist-vars('docType'))
        case 'persons' case 'orgs' return controller:forward-html('/templates/person.html', $exist-vars)
        case 'thematicCommentaries' return controller:forward-html('/templates/var.html', $exist-vars)
        default return controller:forward-html('/templates/document.html', $exist-vars)
    case 'xml' return controller:forward-xml($exist-vars)
    default return controller:error($exist-vars, 404)
};

declare %private function controller:etag($path as xs:string) as xs:string {
    let $lastChanged := 
        (: reload index page every day because of word of the day and what happened on … :)
        if(contains($path, 'Index')) then config:getDateTimeOfLastDBUpdate() || current-date()
        else config:getDateTimeOfLastDBUpdate()
    let $urlParams := string-join(for $i in request:get-parameter-names() order by $i return request:get-parameter($i, ''), '')
    return
        util:hash($path || $lastChanged || $urlParams, 'md5')
};
