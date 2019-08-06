/*************************************************************************
 *
 *  $RCSfile$
 *
 *  $Revision$
 *
 *  last change: $Author$ $Date$
 *
 *  The Contents of this file are made available subject to the terms of
 *  either of the following licenses
 *
 *         - GNU General Public License Version 2.1
 *
 *  Planamesa, Inc., 2005-2007
 *
 *  GNU General Public License Version 2.1
 *  =============================================
 *  Copyright 2005-2007 by Planamesa, Inc. (OPENSTEP@neooffice.org)
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU General Public
 *  License version 2.1, as published by the Free Software Foundation.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public
 *  License along with this library; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston,
 *  MA  02111-1307  USA
 *
 ************************************************************************/

// common.mm

// This file contains functions and utilities that are common to the parsing
// of all of the OpenOffice.org file types.  This includes basic XML node
// text extraction and parsing of the meta.xml file included with multiple
// types of OOo files.

// Planamesa, Inc.
// 4/27/05

#include "common.h"
#include "minizip/unzip.h"
#include <CoreServices/CoreServices.h> // for Metadata key references

///// constants /////

#define UNZIP_BUFFER_SIZE 4096

///// functions /////

/**
 * Parse a meta.xml file into keys for spotlight.  This maps relevant
 * metainformation into spotlight keys
 *
 * @param contentNSData		XML file with meta.xml extraction
 * @param spotlightDict		spotlight dictionary to be filled with
 *				metainformation
 */

void ParseMetaXML(NSData *metaNSData, CFMutableDictionaryRef spotlightDict)
{
    if(!metaNSData || ![metaNSData length] || !spotlightDict)
		return;
	
	// construct an XML parser
	
    NSXMLDocument *xmlTree = [[NSXMLDocument alloc] initWithData:metaNSData options:NSXMLNodeOptionsNone error:nil];
    if(!xmlTree)
        return;
    
    [xmlTree autorelease];
    
    NSMutableString *textData=[NSMutableString stringWithCapacity:kTextExtractionCapacity];
    if (!textData)
        return;
    
	// get the document title.  This is not necessarily the file name
	
	ExtractNodeText(CFSTR("dc:title"), xmlTree, textData);
	if([textData length])
	{
        NSString *textCopy=[NSString stringWithString:textData];
        [textData setString:@""];
        CFDictionaryAddValue(spotlightDict, kMDItemTitle, (CFStringRef)textCopy);
 	}
	
	// get the document description
	
	ExtractNodeText(CFSTR("dc:description"), xmlTree, textData);
    if([textData length])
	{
        NSString *textCopy=[NSString stringWithString:textData];
        [textData setString:@""];
        CFDictionaryAddValue(spotlightDict, kMDItemComment, (CFStringRef)textCopy);
	}
	
	// get the document authors.
		
	CFMutableArrayRef authors=CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
	ExtractNodeText(CFSTR("dc:creator"), xmlTree, textData);
	if([textData length])
	{
        NSString *textCopy=[NSString stringWithString:textData];
        [textData setString:@""];
		CFArrayAppendValue(authors, (CFStringRef)[NSString stringWithString:textCopy]);
	}
	ExtractNodeText(CFSTR("meta:initial-creator"), xmlTree, textData);
    if([textData length])
    {
        NSString *textCopy=[NSString stringWithString:textData];
        [textData setString:@""];
        CFArrayAppendValue(authors, (CFStringRef)textCopy);
	}
	if(CFArrayGetCount(authors) > 0)
	{
		CFDictionaryAddValue(spotlightDict, kMDItemAuthors, authors);
	}
	CFRelease(authors);
	
	// extract document keywords. We'll treat the subject as another keyword as well.
	
	ExtractNodeText(CFSTR("dc:subject"), xmlTree, textData, @"\\");
	ExtractNodeText(CFSTR("meta:keyword"), xmlTree, textData, @"\\");
    if([textData length])
    {
		CFArrayRef keywordArray=CFStringCreateArrayBySeparatingStrings(kCFAllocatorDefault, (CFStringRef)textData, CFSTR("\\"));
		if(keywordArray)
		{
			CFDictionaryAddValue(spotlightDict, kMDItemKeywords, keywordArray);
			CFRelease(keywordArray);
		}
		else
		{
			// we just didn't have a separator, so treat the text as a single keyword.
			// we still need to insert it as an array as that's the type spotlight
			// expects
			
			CFMutableArrayRef keywordArray=CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
			CFArrayAppendValue(keywordArray, (CFStringRef)textData);
			CFDictionaryAddValue(spotlightDict, kMDItemKeywords, keywordArray);
			CFRelease(keywordArray);
		}
	}
}

/**
 * Given a node of a CoreFoundation XML structure, extracxt any
 * text content from that node or recurse on the node's children as
 * appropriate.
 *
 * @param elementPrefix	element tag names are examined for this prefix.  When
 *			encountered, all text data child nodes will have their
 *			content concatenated onto the mutable data
 * @param xmlTreeNode	current tree representation of the node being parsed
 * @param textData	when the first element is found with the given prefix,
 *			all of the child text nodes of that element will
 *			have their content appended onto this mutable data
 *			elemnet.
 * @param separatorChar	character used to separate consecutive text nodes in
 *			the metadata
 * @param saveText	true to save NSData node content as text, FALSE to just
 *			recurse into element children
 */
void ExtractNodeText(CFStringRef elementPrefix, NSXMLNode *xmlTreeNode, NSMutableString *textData, NSString *separatorString, bool saveText)
{
    if (!elementPrefix || !xmlTreeNode || !textData)
        return;
    
    if([xmlTreeNode isKindOfClass:[NSXMLDocument class]])
    {
        xmlTreeNode=[(NSXMLDocument *)xmlTreeNode rootElement];
        if(!xmlTreeNode)
            return;
    }
    
	bool extractText=saveText;
    if([xmlTreeNode kind]==NSXMLElementKind)
    {
        NSString *tagName=[xmlTreeNode name];
        if(tagName && [tagName hasPrefix:(NSString *)elementPrefix])
        {
            // we found one of our text elements that contains the
            // text and not the higher up of the children.
            // start extracting text
            
            extractText=true;
        }
    }
	
    if([xmlTreeNode kind]==NSXMLDocumentKind || [xmlTreeNode kind]==NSXMLElementKind)
	{
        NSArray<NSXMLNode *> *theChildren=[xmlTreeNode children];
        for(NSXMLNode *theChild in theChildren)
		{
            if(!theChild)
                continue;
            
            if([theChild kind]==NSXMLTextKind && extractText)
			{
                NSString *theText=[theChild stringValue];
                if(theText && [theText length])
                {
                    // separate consecutive strings by whitespace
                    if([textData length])
                        [textData appendString:separatorString];
                    [textData appendString:theText];
                }
			}
            else if([theChild kind]==NSXMLElementKind)
			{
				// recurse down into all elements, extracting text according to whether we're
				// embedded within text nodes
				ExtractNodeText(elementPrefix, theChild, textData, separatorString, extractText);
			}
		}
	}
}

/**
 * Given a node of a CoreFoundation XML structure, extracxt any
 * text content from attributes of that node.
 *
 * The text data is attempted to be extracted with UTF8 encoding, in
 * internal representation (no byte ordering marker)
 *
 * @param elementPrefix	element tag names are examined for this prefix.  When
 *			encountered, all of these nodes will have their attributes examined
 * @param attributeName	name of the attribute whose value should be extracted
 * @param xmlTreeNode	current tree representation of the node being parsed
 * @param textData	when elements are found with the given elementPrefix, any
 *					attribute with the specified name will have its value
 *					appended to the end of this mutable data, along with a
 *					the separatorChar separator
 * @param separatorChar	UTF8 character used to separate consecutive attribute values in
 *			the metadata
 * @param saveText	true to save NSData node content as text, FALSE to just
 *			recurse into element children
 */
void ExtractNodeAttributeValue(CFStringRef elementPrefix, CFStringRef attributeName, NSXMLNode *xmlTreeNode, NSMutableString *textData, NSString *separatorString)
{
    if (!elementPrefix || !attributeName || !xmlTreeNode || !textData)
        return;
    
    if([xmlTreeNode isKindOfClass:[NSXMLDocument class]])
    {
        xmlTreeNode=[(NSXMLDocument *)xmlTreeNode rootElement];
        if(!xmlTreeNode)
            return;
    }
    
    // check if the element matches our prefix and extract relevant attribute values
    
    if([xmlTreeNode kind]==NSXMLElementKind)
    {
        NSString *tagName=[xmlTreeNode name];
        if(tagName && [tagName hasPrefix:(NSString *)elementPrefix] && [xmlTreeNode isKindOfClass:[NSXMLElement class]])
        {
            // we found one of our elements we're searching for.  Check to see if it has an
            // appropriately named attribute
            
            NSXMLNode *xmlAttribute=[(NSXMLElement *)xmlTreeNode attributeForName:(NSString *)attributeName];
            if(xmlAttribute && [xmlAttribute kind]==NSXMLAttributeKind)
            {
                NSString *theText=[xmlAttribute stringValue];
                if(theText && [theText length])
                {
                    // separate consecutive strings by whitespace
                    if([textData length])
                        [textData appendString:separatorString];
                    [textData appendString:theText];
                }
            }
        }
    }

	// recurse on any children to search for additional elements that may have other attributes
	
    if([xmlTreeNode kind]==NSXMLDocumentKind || [xmlTreeNode kind]==NSXMLElementKind)
    {
        NSArray<NSXMLNode *> *theChildren=[xmlTreeNode children];
        for(NSXMLNode *theChild in theChildren)
        {
            if(!theChild)
                continue;
            
            if([theChild kind]==NSXMLElementKind)
            {
                // recurse down into all elements, extracting text according to whether we're
                // embedded within text nodes
                ExtractNodeAttributeValue(elementPrefix, attributeName, theChild, textData, separatorString);
            }
        }
    }
}

/**
 * Given a path to a zip archive, extract the content of an individual file
 * of that zip archive into a mutable data structure.
 *
 * The file is attempted to be extracted using UTF8 encoding.
 *
 * @param pathToArhive		path to the zip archive on disk
 * @param fileToExtract		file from the archive that should be extracted
 * @param fileContents		mutable data that should be filled with the
 *				contents of that subfile.  File content
 *				will be appended onto any preexisting data
 *				already in the ref.
 * @return noErr on success, else OS error code
 */
OSErr ExtractZipArchiveContent(CFStringRef pathToArchive, const char *fileToExtract, NSMutableData *fileContents)
{
	OSErr ret = -50;
    
    if (!pathToArchive || !fileToExtract || !strlen(fileToExtract) || !fileContents)
        return(ret);
    
	// extract the path as UTF-8 for internationalization
	
	CFIndex numChars=CFStringGetLength(pathToArchive);
	CFRange rangeToConvert={0,numChars};
	CFIndex numBytesUsed=0;
	
	if(!CFStringGetBytes(pathToArchive, rangeToConvert, kCFStringEncodingUTF8, 0, false, NULL, 0, &numBytesUsed))
		return(ret);
	UInt8 *filePath=new UInt8[numBytesUsed+1];
	memset(filePath, '\0', numBytesUsed+1);
	CFStringGetBytes(pathToArchive, rangeToConvert, kCFStringEncodingUTF8, 0, false, filePath, numBytesUsed+1, NULL);
		
	// open the "content.xml" file living within the sxw and read it into
	// a NSData structure for use with other CoreFoundation elements.
	
	unzFile f = unzOpen((const char *)filePath);
	if (f)
	{
		if (unzLocateFile(f, fileToExtract, 0) == UNZ_OK)
		{
			if (unzOpenCurrentFile(f) == UNZ_OK)
			{
				ret = noErr;

				unsigned char buf[UNZIP_BUFFER_SIZE];
				int bytesRead = 0;
				while ((bytesRead = unzReadCurrentFile(f, buf, UNZIP_BUFFER_SIZE)) > 0)
                    [fileContents appendBytes:buf length:bytesRead];

				unzCloseCurrentFile(f);
			}
		}

		unzClose(f);
	}
	
	delete[] filePath;
	
	if (ret == noErr && ![fileContents length])
		return(-50);

	return(ret);
}

/**
 * Parse a styles.xml file of an OOo formatted file into for spotlight to index
 * header and footer content
 *
 * @param styleNSData		XML file with styles.xml extaction
 * @param spotlightDict		spotlight dictionary to be filled wih the text content
 */
void ParseStylesXML(NSData *stylesNSData, CFMutableDictionaryRef spotlightDict)
{
    if(!stylesNSData || ![stylesNSData length] || !spotlightDict)
		return;
	
	// instantiate an XML parser on the content.xml file and extract
	// content of appropriate header and footer nodes
	
    NSXMLDocument *xmlTree = [[NSXMLDocument alloc] initWithData:stylesNSData options:NSXMLNodeOptionsNone error:nil];
    if(!xmlTree)
        return;
    
    [xmlTree autorelease];
    
    NSMutableString *textData=[NSMutableString stringWithCapacity:kTextExtractionCapacity];
    if (!textData)
        return;
    
	ExtractNodeText(CFSTR("style:header"), xmlTree, textData);
    if([textData length])
        [textData appendString:@" "];
	ExtractNodeText(CFSTR("style:footer"), xmlTree, textData);
	
	// add the data as a text node for spotlight indexing
    
    if([textData length])
    {
        CFStringRef previousText=(CFStringRef)CFDictionaryGetValue(spotlightDict, kMDItemTextContent);
        if(previousText)
        {
            // append this text to the existing set
            if(CFStringGetLength(previousText))
            {
                [textData insertString:@" " atIndex:0];
                [textData insertString:(NSString *)previousText atIndex:0];
            }
            CFDictionaryReplaceValue(spotlightDict, kMDItemTextContent, (CFStringRef)textData);
        }
        else
        {
            CFDictionaryAddValue(spotlightDict, kMDItemTextContent, (CFStringRef)textData);
        }
    }
}
