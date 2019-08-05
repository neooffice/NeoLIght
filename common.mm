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
    if(!metaNSData || [metaNSData length] || !spotlightDict)
		return;
	
	// construct an XML parser
	
	CFDictionaryRef errorDict=NULL;
	CFXMLTreeRef cfXMLTree=CFXMLTreeCreateFromDataWithError(kCFAllocatorDefault, (CFDataRef)metaNSData, NULL, kCFXMLParserReplacePhysicalEntities, kCFXMLNodeCurrentVersion, &errorDict);
	if(errorDict)
	{
		// errors happened during our XML parsing.  Abort our interpretation and return.
		
		CFRelease(errorDict);
        if (cfXMLTree)
            CFRelease(cfXMLTree);
		return;
	}
    else if(!cfXMLTree)
        return;
    
    NSMutableData *theData=[NSMutableData dataWithCapacity:kTextExtractionCapacity];
    if (!theData)
    {
        if (cfXMLTree)
            CFRelease(cfXMLTree);
        return;
    }
    
	// get the document title.  This is not necessarily the file name
	
	ExtractNodeText(CFSTR("dc:title"), cfXMLTree, theData);
	if([theData length])
	{
		CFStringRef theText=CFStringCreateWithBytes(kCFAllocatorDefault, (const UInt8 *)[theData bytes], [theData length], kTextExtractionEncoding, false);
		CFDictionaryAddValue(spotlightDict, kMDItemTitle, theText);
		CFRelease(theText);
		
        [theData setData:[NSData data]];
	}
	
	// get the document description
	
	ExtractNodeText(CFSTR("dc:description"), cfXMLTree, theData);
    if([theData length])
	{
		CFStringRef theText=CFStringCreateWithBytes(kCFAllocatorDefault, (const UInt8 *)[theData bytes], [theData length], kTextExtractionEncoding, false);
		CFDictionaryAddValue(spotlightDict, kMDItemComment, theText);
		CFRelease(theText);
		
        [theData setData:[NSData data]];
	}
	
	// get the document authors.
		
	CFMutableArrayRef authors=CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
	ExtractNodeText(CFSTR("dc:creator"), cfXMLTree, theData);
	if([theData length])
	{
		CFStringRef theText=CFStringCreateWithBytes(kCFAllocatorDefault, (const UInt8 *)[theData bytes], [theData length], kTextExtractionEncoding, false);
		CFArrayAppendValue(authors, theText);
		CFRelease(theText);
		
		[theData setData:[NSData data]];
	}
	ExtractNodeText(CFSTR("meta:initial-creator"), cfXMLTree, theData);
    if([theData length])
    {
        CFStringRef theText=CFStringCreateWithBytes(kCFAllocatorDefault, (const UInt8 *)[theData bytes], [theData length], kTextExtractionEncoding, false);
		CFArrayAppendValue(authors, theText);
		CFRelease(theText);
		
        [theData setData:[NSData data]];
	}
	if(CFArrayGetCount(authors) > 0)
	{
		CFDictionaryAddValue(spotlightDict, kMDItemAuthors, authors);
	}
	CFRelease(authors);
	
	// extract document keywords. We'll treat the subject as another keyword as well.
	
	ExtractNodeText(CFSTR("dc:subject"), cfXMLTree, theData, '\\');
	ExtractNodeText(CFSTR("meta:keyword"), cfXMLTree, theData, '\\');
    if([theData length])
    {
        CFStringRef theText=CFStringCreateWithBytes(kCFAllocatorDefault, (const UInt8 *)[theData bytes], [theData length], kTextExtractionEncoding, false);
		CFArrayRef keywordArray=CFStringCreateArrayBySeparatingStrings(kCFAllocatorDefault, theText, CFSTR("\\"));
		if(keywordArray)
		{
			CFDictionaryAddValue(spotlightDict, kMDItemKeywords, keywordArray);
			CFRelease(keywordArray);
		}
		else if(CFStringGetLength(theText)!=0)
		{
			// we just didn't have a separator, so treat the text as a single keyword.
			// we still need to insert it as an array as that's the type spotlight
			// expects
			
			CFMutableArrayRef keywordArray=CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
			CFArrayAppendValue(keywordArray, theText);
			CFDictionaryAddValue(spotlightDict, kMDItemKeywords, keywordArray);
			CFRelease(keywordArray);
		}
		CFRelease(theText);
	}
	
	// clean up and return
	
	CFRelease(cfXMLTree);
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
void ExtractNodeText(CFStringRef elementPrefix, CFXMLTreeRef xmlTreeNode, NSMutableData *textData, TextExtractionCharType separatorChar, bool saveText)
{
	bool extractText=saveText;
	CFXMLNodeRef theNode=CFXMLTreeGetNode(xmlTreeNode);
	if(CFXMLNodeGetTypeCode(theNode)==kCFXMLNodeTypeElement)
	{
		CFStringRef tagName=CFXMLNodeGetString(theNode);
		if(CFStringHasPrefix(tagName, elementPrefix))
		{
			// we found one of our text elements that contains the
			// text and not the higher up of the children.
			// start extracting text
			
			extractText=true;
		}
	}
	
	if((CFXMLNodeGetTypeCode(theNode)==kCFXMLNodeTypeDocument) || (CFXMLNodeGetTypeCode(theNode)==kCFXMLNodeTypeElement))
	{
		CFIndex numChildren=CFTreeGetChildCount(xmlTreeNode);
		CFXMLTreeRef *theChildren=new CFXMLTreeRef[numChildren];
		CFTreeGetChildren(xmlTreeNode, theChildren);
		for(CFIndex i=0; i<numChildren; i++)
		{
			if((CFXMLNodeGetTypeCode(CFXMLTreeGetNode(theChildren[i]))==kCFXMLNodeTypeText) && extractText)
			{
				CFStringRef theText=CFXMLNodeGetString(CFXMLTreeGetNode(theChildren[i]));
				// separate consecutive strings by whitespace
				if([textData length])
				{
                    [textData appendBytes:&separatorChar length:sizeof(TextExtractionCharType)];
				}
				TextExtractionCharType *utfText=new TextExtractionCharType[CFStringGetLength(theText)+1];
				memset(utfText, '\0', (CFStringGetLength(theText)+1)*sizeof(TextExtractionCharType));
				CFRange extractRange;
				extractRange.location=0;
				extractRange.length=CFStringGetLength(theText);
				CFStringGetBytes(theText, extractRange, kTextExtractionEncoding, ' ', false, (UInt8 *)utfText, (CFStringGetLength(theText)+1)*sizeof(TextExtractionCharType), NULL);
				[textData appendBytes:utfText length:CFStringGetLength(theText)*sizeof(TextExtractionCharType)];
				delete[] utfText;
			}
			else if(CFXMLNodeGetTypeCode(CFXMLTreeGetNode(theChildren[i]))==kCFXMLNodeTypeElement)
			{
				// recurse down into all elements, extracting text according to whether we're
				// embedded within text nodes
				ExtractNodeText(elementPrefix, theChildren[i], textData, separatorChar, extractText);
			}
		}
		delete[] theChildren;
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
void ExtractNodeAttributeValue(CFStringRef elementPrefix, CFStringRef attributeName, CFXMLTreeRef xmlTreeNode, NSMutableData *textData, TextExtractionCharType separatorChar)
{
	CFXMLNodeRef theNode=CFXMLTreeGetNode(xmlTreeNode);
	
	// check if the element matches our prefix and extract relevant attribute values
	
	if(CFXMLNodeGetTypeCode(theNode)==kCFXMLNodeTypeElement)
	{
		CFStringRef tagName=CFXMLNodeGetString(theNode);
		if(CFStringHasPrefix(tagName, elementPrefix))
		{
			// we found one of our elements we're searching for.  Check to see if it has an
			// appropriately named attribute
			
			CFXMLElementInfo *elementInfo=(CFXMLElementInfo *)CFXMLNodeGetInfoPtr(theNode);
			if(elementInfo && elementInfo->attributes && CFDictionaryContainsKey(elementInfo->attributes, attributeName))
			{
				const void *attributeValue=CFDictionaryGetValue(elementInfo->attributes, attributeName);
				if(CFGetTypeID(attributeValue)==CFStringGetTypeID())
				{
					CFStringRef theText=(CFStringRef)attributeValue;
					// separate consecutive strings by whitespace
					if([textData length])
					{
                        [textData appendBytes:&separatorChar length:sizeof(TextExtractionCharType)];
					}
					TextExtractionCharType *utfText=new TextExtractionCharType[CFStringGetLength(theText)+1];
					memset(utfText, '\0', (CFStringGetLength(theText)+1)*sizeof(TextExtractionCharType));
					CFRange extractRange;
					extractRange.location=0;
					extractRange.length=CFStringGetLength(theText);
					CFStringGetBytes(theText, extractRange, kTextExtractionEncoding, ' ', false, (UInt8 *)utfText, (CFStringGetLength(theText)+1)*sizeof(TextExtractionCharType), NULL);
                    [textData appendBytes:utfText length:CFStringGetLength(theText)*sizeof(TextExtractionCharType)];
					delete[] utfText;
				}
			}
		}
	}
	
	// recurse on any children to search for additional elements that may have other attributes
	
	if((CFXMLNodeGetTypeCode(theNode)==kCFXMLNodeTypeDocument) || (CFXMLNodeGetTypeCode(theNode)==kCFXMLNodeTypeElement))
	{
		CFIndex numChildren=CFTreeGetChildCount(xmlTreeNode);
		CFXMLTreeRef *theChildren=new CFXMLTreeRef[numChildren];
		CFTreeGetChildren(xmlTreeNode, theChildren);
		for(CFIndex i=0; i<numChildren; i++)
		{
			if(CFXMLNodeGetTypeCode(CFXMLTreeGetNode(theChildren[i]))==kCFXMLNodeTypeElement)
			{
				// recurse down into all elements, extracting text according to whether we're
				// embedded within text nodes
				ExtractNodeAttributeValue(elementPrefix, attributeName, theChildren[i], textData, separatorChar);
			}
		}
		delete[] theChildren;
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
    if(!stylesNSData || [stylesNSData length] || !spotlightDict)
		return;
	
	// instantiate an XML parser on the content.xml file and extract
	// content of appropriate header and footer nodes
	
	CFDictionaryRef errorDict=NULL;
	CFXMLTreeRef cfXMLTree=CFXMLTreeCreateFromDataWithError(kCFAllocatorDefault, (CFDataRef)stylesNSData, NULL, kCFXMLParserReplacePhysicalEntities, kCFXMLNodeCurrentVersion, &errorDict);
	if(errorDict)
	{
		// errors happened during our XML parsing.  Abort our interpretation and return.
		
		CFRelease(errorDict);
        if (cfXMLTree)
            CFRelease(cfXMLTree);
		return;
	}
    else if(!cfXMLTree)
        return;
    
    NSMutableData *textData=[NSMutableData dataWithCapacity:kTextExtractionCapacity];
    if (!textData)
    {
        if (cfXMLTree)
            CFRelease(cfXMLTree);
        return;
    }
    
	ExtractNodeText(CFSTR("style:header"), cfXMLTree, textData);
        TextExtractionCharType space=' ';
    [textData appendBytes:&space length:sizeof(TextExtractionCharType)];
	ExtractNodeText(CFSTR("style:footer"), cfXMLTree, textData);
	
	// add the data as a text node for spotlight indexing
	
	CFStringRef theText=CFStringCreateWithBytes(kCFAllocatorDefault, (const UInt8 *)[textData bytes], [textData length], kTextExtractionEncoding, false);
	if(CFDictionaryGetValue(spotlightDict, kMDItemTextContent))
	{
	    // append this text to the existing set
	    CFStringRef previousText=(CFStringRef)CFDictionaryGetValue(spotlightDict, kMDItemTextContent);
	    CFMutableStringRef newText=CFStringCreateMutable(kCFAllocatorDefault, 0);
	    CFStringAppend(newText, previousText);
	    CFStringAppendCharacters(newText, &space, 1);
	    CFStringAppend(newText, theText);
	    CFDictionaryReplaceValue(spotlightDict, kMDItemTextContent, newText);
	    CFRelease(newText);
	}
	else
	{
	    CFDictionaryAddValue(spotlightDict, kMDItemTextContent, theText);
	}
	CFRelease(theText);
	
	// cleanup and return
	
	CFRelease(cfXMLTree);
}
