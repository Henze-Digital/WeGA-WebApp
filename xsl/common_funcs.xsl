<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="http://www.w3.org/1999/xhtml" 
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
    xmlns:wega="http://xquery.weber-gesamtausgabe.de/webapp/functions/utilities" 
    xmlns:tei="http://www.tei-c.org/ns/1.0" 
    xmlns:xhtml="http://www.w3.org/1999/xhtml"
    xmlns:rng="http://relaxng.org/ns/structure/1.0" 
    xmlns:functx="http://www.functx.com" 
    xmlns:xs="http://www.w3.org/2001/XMLSchema" 
    xmlns:mei="http://www.music-encoding.org/ns/mei" version="2.0">
    
    <!--  *********************************************  -->
    <!--  *             Global Functions              *  -->
    <!--  *********************************************  -->

    <xsl:function name="wega:getAuthorFromTeiDoc" as="xs:string">
        <xsl:param name="docID" as="xs:string"/>
        <!-- construct path to File (collection function does not work! cf. http://exist.2174344.n4.nabble.com/error-with-collection-in-XSLT-within-eXist-td2189008.html) -->
        <xsl:variable name="doc" select="wega:doc($docID)"/>
        <xsl:choose>
            <xsl:when test="wega:isWork($docID) and exists($doc)">
                <xsl:choose>
                    <xsl:when test="$doc//mei:titleStmt/mei:respStmt/mei:persName[@role = 'cmp'][1]/@dbkey">
                        <xsl:value-of select="$doc//mei:titleStmt/mei:respStmt/mei:persName[@role = 'cmp'][1]/string(@dbkey)"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="wega:getOption('anonymusID')"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:when>
            <xsl:when test="wega:isDiary($docID) and exists($doc)">
                <xsl:value-of select="'A002068'"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:choose>
                    <xsl:when test="exists($doc)">
                        <xsl:choose>
                            <xsl:when test="$doc//tei:fileDesc//tei:titleStmt//tei:author[1]/@key">
                                <xsl:value-of select="$doc//tei:fileDesc//tei:titleStmt//tei:author[1]/string(@key)"/>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:value-of select="wega:getOption('anonymusID')"/>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="''"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <xsl:function name="wega:getCollectionPath" as="xs:string">
        <xsl:param name="docID" as="xs:string"/>
        <xsl:value-of select="string-join(($data-collection-path, wega:get-doctype-by-id($docID), concat(substring($docID, 1, 5), 'xx')), '/')"/>
    </xsl:function>

    <xsl:function name="wega:getOption" as="xs:string">
        <xsl:param name="key" as="xs:string"/>
        <xsl:value-of select="wega:doc($optionsFile)//entry[@xml:id = $key]/text()"/>
    </xsl:function>

    <xsl:function name="wega:getLanguageString" as="xs:string">
        <xsl:param name="key" as="xs:string"/>
        <xsl:param name="lang" as="xs:string"/>
        <xsl:value-of select="wega:doc(wega:getOption(concat('dic_', $lang)))//entry[@xml:id = $key]/text()"/>
    </xsl:function>

    <xsl:function name="wega:isPerson" as="xs:boolean">
        <xsl:param name="docID" as="xs:string"/>
        <xsl:choose>
            <xsl:when test="matches($docID, '^A00[0-9A-F]{4}$')">
                <xsl:value-of select="true()"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="false()"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <xsl:function name="wega:isIconography" as="xs:boolean">
        <xsl:param name="docID" as="xs:string"/>
        <xsl:choose>
            <xsl:when test="matches($docID, '^A01\d{4}$')">
                <xsl:value-of select="true()"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="false()"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <xsl:function name="wega:isWork" as="xs:boolean">
        <xsl:param name="docID" as="xs:string"/>
        <xsl:choose>
            <xsl:when test="matches($docID, '^A02\d{4}$')">
                <xsl:value-of select="true()"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="false()"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <xsl:function name="wega:isWriting" as="xs:boolean">
        <xsl:param name="docID" as="xs:string"/>
        <xsl:choose>
            <xsl:when test="matches($docID, '^A03\d{4}$')">
                <xsl:value-of select="true()"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="false()"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <xsl:function name="wega:isLetter" as="xs:boolean">
        <xsl:param name="docID" as="xs:string"/>
        <xsl:choose>
            <xsl:when test="matches($docID, '^A04\d{4}$')">
                <xsl:value-of select="true()"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="false()"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <xsl:function name="wega:isNews" as="xs:boolean">
        <xsl:param name="docID" as="xs:string"/>
        <xsl:choose>
            <xsl:when test="matches($docID, '^A05\d{4}$')">
                <xsl:value-of select="true()"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="false()"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <xsl:function name="wega:isDiary" as="xs:boolean">
        <xsl:param name="docID" as="xs:string"/>
        <xsl:choose>
            <xsl:when test="matches($docID, '^A06\d{4}$')">
                <xsl:value-of select="true()"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="false()"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <xsl:function name="wega:isVar" as="xs:boolean">
        <xsl:param name="docID" as="xs:string"/>
        <xsl:choose>
            <xsl:when test="matches($docID, '^A07\d{4}$')">
                <xsl:value-of select="true()"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="false()"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
    <xsl:function name="wega:isBiblio" as="xs:boolean">
        <xsl:param name="docID" as="xs:string"/>
        <xsl:choose>
            <xsl:when test="matches($docID, '^A11\d{4}$')">
                <xsl:value-of select="true()"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="false()"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
    <xsl:function name="wega:isPlace" as="xs:boolean">
        <xsl:param name="docID" as="xs:string"/>
        <xsl:choose>
            <xsl:when test="matches($docID, '^A13\d{4}$')">
                <xsl:value-of select="true()"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="false()"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
    <xsl:function name="wega:isSource" as="xs:boolean">
        <xsl:param name="docID" as="xs:string"/>
        <xsl:choose>
            <xsl:when test="matches($docID, '^A22\d{4}$')">
                <xsl:value-of select="true()"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="false()"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
    <xsl:function name="wega:isOrg" as="xs:boolean">
        <xsl:param name="docID" as="xs:string"/>
        <xsl:choose>
            <xsl:when test="matches($docID, '^A08\d{4}$')">
                <xsl:value-of select="true()"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="false()"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
    <xsl:function name="wega:isThematicCom" as="xs:boolean">
        <xsl:param name="docID" as="xs:string"/>
        <xsl:choose>
            <xsl:when test="matches($docID, '^A09\d{4}$')">
                <xsl:value-of select="true()"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="false()"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
    <xsl:function name="wega:isDocument" as="xs:boolean">
        <xsl:param name="docID" as="xs:string"/>
        <xsl:choose>
            <xsl:when test="matches($docID, '^A10\d{4}$')">
                <xsl:value-of select="true()"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="false()"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
    <xsl:function name="wega:get-doctype-by-id" as="xs:string?">
        <xsl:param name="docID" as="xs:string"/>
        <xsl:choose>
            <xsl:when test="wega:isPerson($docID)">
                <xsl:value-of select="'persons'"/>
            </xsl:when>
            <xsl:when test="wega:isIconography($docID)">
                <xsl:value-of select="'iconography'"/>
            </xsl:when>
            <xsl:when test="wega:isWork($docID)">
                <xsl:value-of select="'works'"/>
            </xsl:when>
            <xsl:when test="wega:isWriting($docID)">
                <xsl:value-of select="'writings'"/>
            </xsl:when>
            <xsl:when test="wega:isLetter($docID)">
                <xsl:value-of select="'letters'"/>
            </xsl:when>
            <xsl:when test="wega:isNews($docID)">
                <xsl:value-of select="'news'"/>
            </xsl:when>
            <xsl:when test="wega:isDiary($docID)">
                <xsl:value-of select="'diaries'"/>
            </xsl:when>
            <xsl:when test="wega:isVar($docID)">
                <xsl:value-of select="'var'"/>
            </xsl:when>
            <xsl:when test="wega:isBiblio($docID)">
                <xsl:value-of select="'biblio'"/>
            </xsl:when>
            <xsl:when test="wega:isPlace($docID)">
                <xsl:value-of select="'places'"/>
            </xsl:when>
            <xsl:when test="wega:isSource($docID)">
                <xsl:value-of select="'sources'"/>
            </xsl:when>
            <xsl:when test="wega:isOrg($docID)">
                <xsl:value-of select="'orgs'"/>
            </xsl:when>
            <xsl:when test="wega:isThematicCom($docID)">
                <xsl:value-of select="'thematicCommentaries'"/>
            </xsl:when>
            <xsl:when test="wega:isDocument($docID)">
                <xsl:value-of select="'documents'"/>
            </xsl:when>
            <xsl:otherwise/>
        </xsl:choose>
    </xsl:function>

    <xsl:function name="wega:createLinkToDoc" as="xs:string?">
        <xsl:param name="docID" as="xs:string"/>
        <xsl:param name="lang" as="xs:string"/>
        <xsl:variable name="authorID">
            <xsl:choose>
                <xsl:when test="wega:isPerson($docID)"/>
                <xsl:when test="wega:isOrg($docID)"/>
                <xsl:otherwise>
                    <xsl:value-of select="wega:getAuthorFromTeiDoc($docID)"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="folder">
            <xsl:choose>
                <xsl:when test="wega:isWork($docID)">
                    <xsl:value-of select="wega:getLanguageString('works', $lang)"/>
                </xsl:when>
                <xsl:when test="wega:isWriting($docID)">
                    <xsl:value-of select="wega:getLanguageString('writings', $lang)"/>
                </xsl:when>
                <xsl:when test="wega:isLetter($docID)">
                    <xsl:value-of select="wega:getLanguageString('correspondence', $lang)"/>
                </xsl:when>
                <xsl:when test="wega:isNews($docID)">
                    <xsl:value-of select="wega:getLanguageString('news', $lang)"/>
                </xsl:when>
                <xsl:when test="wega:isDiary($docID)">
                    <xsl:value-of select="wega:getLanguageString('diaries', $lang)"/>
                </xsl:when>
                <xsl:when test="wega:isThematicCom($docID)">
                    <xsl:value-of select="wega:getLanguageString('thematicCommentaries', $lang)"/>
                </xsl:when>
                <xsl:when test="wega:isDocument($docID)">
                    <xsl:value-of select="wega:getLanguageString('documents', $lang)"/>
                </xsl:when>
                <xsl:otherwise/>
            </xsl:choose>
        </xsl:variable>
        <xsl:choose>
            <xsl:when test="wega:isPerson($docID) or wega:isOrg($docID)">
                <xsl:value-of select="concat(wega:join-path-elements(($baseHref, $lang, $docID)), '.html')"/>
            </xsl:when>
            <xsl:when test="exists($folder) and $authorID ne ''">
                <xsl:value-of select="concat(wega:join-path-elements(($baseHref, $lang, $authorID, $folder, $docID)), '.html')"/>
            </xsl:when>
            <xsl:otherwise/>
        </xsl:choose>
    </xsl:function>

    <xsl:function name="wega:obfuscateEmail" as="xs:string">
        <xsl:param name="email" as="xs:string"/>
        <xsl:value-of select="string-join(tokenize($email, ' [at] '), ' [ at ] ')"/>
    </xsl:function>

    <xsl:function name="wega:encryptString" as="xs:integer+">
        <xsl:param name="string" as="xs:string"/>
        <xsl:param name="salt" as="xs:integer?"/>
        <xsl:variable name="mySalt" as="xs:integer">
            <xsl:choose>
                <xsl:when test="$salt != 0">
                    <xsl:value-of select="$salt"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="7"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:sequence select="for $k in string-to-codepoints($string) return $k * $mySalt"/>
    </xsl:function>

    <xsl:function name="wega:addCurrencySymbolIfNecessary" as="element(xhtml:span)?">
        <xsl:param name="measure" as="element(tei:measure)"/>
        <!-- Wenn kein Währungssymbol angegeben ist, setzen wir eins hinzu -->
        <xsl:if test="matches(normalize-space($measure),'^\d+\.?$') and $measure/@quantity &gt; 0">
            <xsl:element name="span">
                <xsl:attribute name="class" select="'tei_supplied'"/>
                <xsl:choose>
                    <xsl:when test="$measure/@unit = 'f'">
                        <xsl:value-of select="' &#402;'"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="concat(' ', $measure/@unit)"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:element>
        </xsl:if>
    </xsl:function>

    <xsl:function name="wega:createLightboxAnchor" as="element()?">
        <xsl:param name="href" as="xs:string"/>
        <xsl:param name="title" as="xs:string"/>
        <xsl:param name="group" as="xs:string"/>
        <!-- muss kleingeschrieben sein! -->
        <xsl:param name="content" as="item()*"/>
        <xsl:variable name="options" as="xs:string" select="concat('group:',$group)"/>
        <xsl:element name="a">
            <xsl:attribute name="href" select="$href"/>
            <xsl:attribute name="class" select="string('lytebox')"/>
            <xsl:attribute name="data-lyte-options" select="$options"/>
            <xsl:attribute name="data-title" select="$title"/>
            <xsl:sequence select="$content"/>
        </xsl:element>
    </xsl:function>

    <xsl:function name="wega:getTextAlignment" as="xs:string">
        <xsl:param name="rend" as="xs:string?"/>
        <xsl:param name="default" as="xs:string"/>
        <xsl:choose>
            <xsl:when test="$rend = ('left', 'right', 'center')">
                <xsl:value-of select="concat('textAlign-', $rend)"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="concat('textAlign-', $default)"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <xsl:function name="wega:computeMedian" as="xs:double?">
        <xsl:param name="numbers" as="xs:double*"/>
        <xsl:variable name="orderedNumbers" as="xs:double*">
            <xsl:for-each select="$numbers">
                <xsl:sort select="."/>
                <xsl:value-of select="."/>
            </xsl:for-each>
        </xsl:variable>
        <xsl:variable name="middle" as="xs:double" select="(count($orderedNumbers) + 1) div 2"/>
        <xsl:value-of select="avg(($orderedNumbers[ceiling($middle)], $orderedNumbers[floor($middle)]))"/>
    </xsl:function>
    
    <xsl:function name="wega:join-path-elements" as="xs:string">
        <xsl:param name="segs" as="xs:string*"/>
        <xsl:value-of select="replace(string-join(('/', $segs), '/'), '/+', '/')"/>
    </xsl:function>
        
    <xsl:function name="wega:hex2dec" as="xs:integer?">
        <!-- Taken from http://blog.sam.liddicott.com/2006/04/xslt-hex-to-decimal-conversion.html -->
        <xsl:param name="str" as="xs:string"/>
        <xsl:if test="$str != ''">
            <xsl:variable name="len" select="string-length($str)"/>
            <xsl:value-of select="
                if ( $len lt 2 ) then string-length(substring-before('0 1 2 3 4 5 6 7 8 9 AaBbCcDdEeFf',$str)) idiv 2
                else wega:hex2dec(substring($str,1,$len - 1))*16 + wega:hex2dec(substring($str,$len))
            "/>
        </xsl:if>
    </xsl:function>
    
    <!-- A wrapper function around doc() which accepts local IDs (e.g. A002068), or local db paths in addition to standard URIs -->
    <xsl:function name="wega:doc" as="document-node()?">
        <xsl:param name="fileIdOrPath" as="xs:string"/>
        <xsl:variable name="uri" as="xs:string">
            <xsl:choose>
                <xsl:when test="wega:get-doctype-by-id($fileIdOrPath)">
                    <xsl:value-of select="concat('xmldb:exist://', wega:getCollectionPath($fileIdOrPath), '/', $fileIdOrPath, '.xml')"/>
                </xsl:when>
                <xsl:when test="starts-with($fileIdOrPath, '/db')">
                    <xsl:value-of select="concat('xmldb:exist://', $fileIdOrPath)"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="$fileIdOrPath"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:choose>
            <xsl:when test="doc-available($uri)">
                <xsl:sequence select="doc($uri)"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:message>XSLT Error in wega:doc(): could not open <xsl:value-of select="$fileIdOrPath"/></xsl:message>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
        
    <!--  *********************************************  -->
    <!--  * Functx - Funktionen http://www.functx.com *  -->
    <!--  *********************************************  -->
    <xsl:function name="functx:replace-multi" as="xs:string?">
        <xsl:param name="arg" as="xs:string?"/>
        <xsl:param name="changeFrom" as="xs:string*"/>
        <xsl:param name="changeTo" as="xs:string*"/>
        <xsl:sequence select="
            if (count($changeFrom) &gt; 0) then functx:replace-multi(replace($arg, $changeFrom[1], functx:if-absent($changeTo[1],'')), $changeFrom[position() &gt; 1], $changeTo[position() &gt; 1])
            else $arg"
        />
    </xsl:function>
    
    <xsl:function name="functx:if-absent" as="item()*">
        <xsl:param name="arg" as="item()*"/>
        <xsl:param name="value" as="item()*"/>
        <xsl:sequence select="if (exists($arg)) then $arg else $value"/>
    </xsl:function>
    
</xsl:stylesheet>