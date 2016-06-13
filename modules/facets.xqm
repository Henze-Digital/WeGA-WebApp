xquery version "3.1" encoding "UTF-8";

(:~
 : WeGA facets XQuery-Modul
 :
 : @author Peter Stadler 
 : @version 2.0
 :)

module namespace facets="http://xquery.weber-gesamtausgabe.de/modules/facets";
declare default collation "?lang=de;strength=primary";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace mei="http://www.music-encoding.org/ns/mei";
declare namespace xhtml="http://www.w3.org/1999/xhtml";
declare namespace exist="http://exist.sourceforge.net/NS/exist";
declare namespace util = "http://exist-db.org/xquery/util";
declare namespace templates="http://exist-db.org/xquery/templates";
import module namespace config="http://xquery.weber-gesamtausgabe.de/modules/config" at "config.xqm";
import module namespace norm="http://xquery.weber-gesamtausgabe.de/modules/norm" at "norm.xqm";
import module namespace lang="http://xquery.weber-gesamtausgabe.de/modules/lang" at "lang.xqm";
import module namespace query="http://xquery.weber-gesamtausgabe.de/modules/query" at "query.xqm";
import module namespace str="http://xquery.weber-gesamtausgabe.de/modules/str" at "str.xqm";
import module namespace core="http://xquery.weber-gesamtausgabe.de/modules/core" at "core.xqm";
import module namespace wdt="http://xquery.weber-gesamtausgabe.de/modules/wdt" at "wdt.xqm";
import module namespace functx="http://www.functx.com";

declare 
    %templates:default("lang", "en")
    function facets:select($node as node(), $model as map(*), $lang as xs:string) as element(xhtml:select) {
        let $facet := $node/data(@name)
        let $facet-items := facets:facets($model('search-results'), $facet, 10, $lang) 
        return
            element {name($node)} {
                $node/@*,
                element option {
                    attribute value {''},
                    lang:get-language-string('all', $lang)
                },
                for $i in $facet-items?* 
                order by $i?label
                return
                    element option {
                        if(map:get($model('filters'), $facet) = $i?value) then 
                            attribute selected {'selected'}
                        else (),
                        attribute value {$i?value},
                        facets:display-term($facet, $i?label, $lang) || ' (' || $i?frequency || ')'
                    }
            }
};

declare function facets:facets($nodes as node()*, $facet as xs:string, $max as xs:integer, $lang as xs:string) as array(*)  {
    switch($facet)
    case 'textType' return facets:from-docType($nodes, $facet, $lang)
    default return facets:createFacets(query:get-facets($nodes, $facet), $max)
};

declare %private function facets:from-docType($collection as node()*, $facet as xs:string, $lang as xs:string) as array(*) {
    [
        for $i in $collection
        group by $docTypePrefix := substring($i/*/@xml:id, 1, 3)
        let $docType := lang:get-language-string($config:wega-docTypes-inverse($docTypePrefix), $lang)
        return 
            map {
                'value' := $config:wega-docTypes-inverse($docTypePrefix),
                'label' := $docType,
                'frequency' := count($i)
            }
    ]
};

(:~
 : Returns list of terms and their frequency in the collection
 :
 : @author Peter Stadler 
 : @param $term
 : @param $data contains frequency
 : @return element
 :)
declare %private function facets:term-callback($term as xs:string, $data as xs:int+) as map()? {
    let $docType := config:get-doctype-by-id($term)
    let $label := 
        if($docType) then wdt:lookup($docType, $term)('label-facets')()
        else str:normalize-space($term)
    return
    map {
        'value' := str:normalize-space($term),
        'label' := $label,
        'frequency' := $data[2]
    }
};

(:~
 : Create facets
 :
 : @author Peter Stadler 
 : @param $collFacets
 : @return element
 :)
declare %private function facets:createFacets($collFacets as item()*, $max as xs:integer) as array(*) {
    [
        util:index-keys($collFacets, '', facets:term-callback#2, $max)
    ]
};

(:~
 : Helper function for localizing facet terms
~:)
declare %private function facets:display-term($facet as xs:string, $term as xs:string, $lang as xs:string) as xs:string {
    switch ($facet)
    case 'docTypeSubClass' case 'docStatus' return lang:get-language-string($term, $lang)
    default return $term
};

declare 
    %templates:default("lang", "en") 
    %templates:wrap
    function facets:document-allFilter($node as node(), $model as map(*), $lang as xs:string) as map(*) {
        map {
            'filterSections' := 
                for $filter in ('persons', 'works', 'places', 'characterNames')
                let $keys := distinct-values($model('doc')//@key[ancestor::tei:text or ancestor::tei:ab][not(ancestor::tei:note)]/tokenize(., '\s+')[config:get-doctype-by-id(.) = $filter])
                let $places := 
                    if($filter = 'places') then distinct-values($model('doc')//tei:settlement[ancestor::tei:text or ancestor::tei:ab][not(ancestor::tei:note)])
                    else ()
                let $characterNames := 
                    if($filter = 'characterNames') then distinct-values($model('doc')//tei:characterName[ancestor::tei:text or ancestor::tei:ab][not(ancestor::tei:note)])
                    else ()
(:                let $log := util:log-system-out($filter || count($characterNames)):)
                return 
                    if(exists($keys)) then map { $filter := $keys}
                    else if(exists($places)) then map { $filter := $places}
                    else if(exists($characterNames)) then map { $filter := $characterNames}
                    else ()
        }
};

declare 
    %templates:default("lang", "en")
    %templates:wrap
    function facets:filter-options($node as node(), $model as map(*), $lang as xs:string) as map(*) {
        map {
            'filterOptions' := 
                (: iterating over filterSection although there's only one key in this map :)
                for $i in map:keys($model('filterSection'))
                    for $j in $model('filterSection')($i)
                    let $label :=
                        switch($i)
                        case 'persons' return query:get-reg-name($j)
                        case 'works' return query:get-reg-title($j)
                        default return $j
                    let $key :=
                        switch($i)
                        case 'places' return string-join(string-to-codepoints(normalize-space($j)) ! string(.), '')
                        case 'characterNames' return string-join(string-to-codepoints(normalize-space($j)) ! string(.), '')
                        default return $j
                    order by $label ascending
                    return map { 'key' := $key, 'label' := $label}
        }
};

declare function facets:filter-body($node as node(), $model as map(*)) as element(div) {
    element {name($node)} {
        $node/@class,
        (: That should be safe because there's always only one key in filterSection :)
        attribute id {map:keys($model('filterSection'))}(:,
        templates:process($node/node(), $model):)
    }
};

declare 
    %templates:default("lang", "en") 
    function facets:filter-head($node as node(), $model as map(*), $lang as xs:string) as element(h2) {
        element {name($node)} {
            $node/@*[not(name(.) = 'href')],
            (: That should be safe because there's always only one key in filterSection :)
            attribute href {'#' || map:keys($model('filterSection'))},
            lang:get-language-string(map:keys($model('filterSection')), $lang)
        }
};

declare function facets:filter-value($node as node(), $model as map(*)) as element(input) {
    element {name($node)} {
        $node/@*[not(name(.) = 'id')],
        attribute value {$model('filterOption')('key')}
    }
};

declare function facets:filter-label($node as node(), $model as map(*)) as element(span) {
    element {name($node)} {
        $node/@*[not(name(.) = 'title')],
        attribute title {$model('filterOption')('label')},
        if(string-length($model('filterOption')('label')) > 30) then 
            substring($model('filterOption')('label'), 1, 30) || '…'
        else $model('filterOption')('label')
    }
};
