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
 *         - GNU Lesser General Public License Version 2.1
 *
 *  Edward Peterlin, 2005
 *
 *  GNU Lesser General Public License Version 2.1
 *  =============================================
 *  Copyright 2005 by Edward Peterlin (OPENSTEP@neooffice.org)
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License version 2.1, as published by the Free Software Foundation.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public
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

// Edward Peterlin
// 4/27/05

#include "common.h"
#include <CoreServices/CoreServices.h> // for Metadata key references

///// constants ////

/**
 * Command used by popen() to construct a file handle extracting a given
 * file out of a zip archive
 */
#define kOpenSubfileCmd		"/usr/bin/unzip -p \"%s\" \"%s\""

///// functions /////

/**
 * Parse a meta.xml file into keys for spotlight.  This maps relevant
 * metainformation into spotlight keys
 *
 * @param contentCFData		XML file with meta.xml extraction
 * @param spotlightDict		spotlight dictionary to be filled with
 *				metainformation
 */
void ParseMetaXML(CFMutableDataRef metaCFData, CFMutableDictionaryRef spotlightDict)
{
	// construct an XML parser
	
	CFXMLTreeRef cfXMLTree=CFXMLTreeCreateFromData(kCFAllocatorDefault, metaCFData, NULL, kCFXMLParserReplacePhysicalEntities, kCFXMLNodeCurrentVersion);
	if(!cfXMLTree)
		return;

	CFMutableDataRef theData=CFDataCreateMutable(kCFAllocatorDefault, 0);
	
	// get the document title.  This is not necessarily the file name
	
	ExtractNodeText(CFSTR("dc:title"), cfXMLTree, theData);
	if(CFDataGetLength(theData))
	{
		CFStringRef theText=CFStringCreateWithBytes(kCFAllocatorDefault, CFDataGetBytePtr(theData), CFDataGetLength(theData), kTextExtractionEncoding, false);
		CFDictionaryAddValue(spotlightDict, kMDItemTitle, theText);
		CFRelease(theText);
		
		CFDataSetLength(theData, 0);
	}
	
	// get the document description
	
	ExtractNodeText(CFSTR("dc:description"), cfXMLTree, theData);
	if(CFDataGetLength(theData))
	{
		CFStringRef theText=CFStringCreateWithBytes(kCFAllocatorDefault, CFDataGetBytePtr(theData), CFDataGetLength(theData), kTextExtractionEncoding, false);
		CFDictionaryAddValue(spotlightDict, kMDItemComment, theText);
		CFRelease(theText);
		
		CFDataSetLength(theData, 0);
	}
	
	// get the document authors.
		
	CFMutableArrayRef authors=CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
	ExtractNodeText(CFSTR("dc:creator"), cfXMLTree, theData);
	if(CFDataGetLength(theData))
	{
		CFStringRef theText=CFStringCreateWithBytes(kCFAllocatorDefault, CFDataGetBytePtr(theData), CFDataGetLength(theData), kTextExtractionEncoding, false);
		CFArrayAppendValue(authors, theText);
		CFRelease(theText);
		
		CFDataSetLength(theData, 0);
	}
	ExtractNodeText(CFSTR("meta:initial-creator"), cfXMLTree, theData);
	if(CFDataGetLength(theData))
	{
		CFStringRef theText=CFStringCreateWithBytes(kCFAllocatorDefault, CFDataGetBytePtr(theData), CFDataGetLength(theData), kTextExtractionEncoding, false);
		CFArrayAppendValue(authors, theText);
		CFRelease(theText);
		
		CFDataSetLength(theData, 0);
	}
	if(CFArrayGetCount(authors) > 0)
	{
		CFDictionaryAddValue(spotlightDict, kMDItemAuthors, authors);
	}
	CFRelease(authors);
	
	// extract document keywords. We'll treat the subject as another keyword as well.
	
	ExtractNodeText(CFSTR("dc:subject"), cfXMLTree, theData, '\\');
	ExtractNodeText(CFSTR("meta:keyword"), cfXMLTree, theData, '\\');
	if(CFDataGetLength(theData))
	{
		CFStringRef theText=CFStringCreateWithBytes(kCFAllocatorDefault, CFDataGetBytePtr(theData), CFDataGetLength(theData), kTextExtractionEncoding, false);
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
		
		CFDataSetLength(theData, 0);
	}
	
	// clean up and return
	
	CFRelease(theData);
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
 * @param saveText	true to save CFDATA node content as text, FALSE to just
 *			recurse into element children
 */
void ExtractNodeText(CFStringRef elementPrefix, CFXMLTreeRef xmlTreeNode, CFMutableDataRef textData, TextExtractionCharType separatorChar, bool saveText)
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
				if(CFDataGetLength(textData) > 0)
				{
					CFDataAppendBytes(textData, (UInt8 *)&separatorChar, sizeof(TextExtractionCharType));
				}
				TextExtractionCharType *utfText=new TextExtractionCharType[CFStringGetLength(theText)+1];
				memset(utfText, '\0', (CFStringGetLength(theText)+1)*sizeof(TextExtractionCharType));
				CFRange extractRange;
				extractRange.location=0;
				extractRange.length=CFStringGetLength(theText);
				CFStringGetBytes(theText, extractRange, kTextExtractionEncoding, ' ', false, (UInt8 *)utfText, (CFStringGetLength(theText)+1)*sizeof(TextExtractionCharType), NULL);
				CFDataAppendBytes(textData, (UInt8 *)utfText, CFStringGetLength(theText)*sizeof(TextExtractionCharType));
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
OSErr ExtractZipArchiveContent(CFStringRef pathToArchive, const char *fileToExtract, CFMutableDataRef fileContents)
{
	// extract the path as UTF-8 for internationalization
	
	CFIndex numChars=CFStringGetLength(pathToArchive);
	CFRange rangeToConvert={0,numChars};
	CFIndex numBytesUsed=0;
	
	if(!CFStringGetBytes(pathToArchive, rangeToConvert, kCFStringEncodingUTF8, 0, false, NULL, 0, &numBytesUsed))
		return(-50);
	UInt8 *filePath=new UInt8[numBytesUsed+1];
	memset(filePath, '\0', numBytesUsed+1);
	CFStringGetBytes(pathToArchive, rangeToConvert, kCFStringEncodingUTF8, 0, false, filePath, numBytesUsed+1, NULL);
		
	// open the "content.xml" file living within the sxw and read it into
	// a CFData structure for use with other CoreFoundation elements.
	
	char *openCmd=new char[strlen(kOpenSubfileCmd)+strlen((char *)filePath)+strlen(fileToExtract)+1];
	memset(openCmd, '\0', strlen(kOpenSubfileCmd)+strlen((char *)filePath)+strlen(fileToExtract)+1);
	sprintf(openCmd, kOpenSubfileCmd, filePath, fileToExtract);
	
	fprintf(stderr, "%s\n", openCmd);
	
	FILE *f=popen(openCmd, "r");
	if(!f)
	{
		delete[] filePath;
		delete[] openCmd;
		return(-50);
	}
	
	unsigned char c;
	while(fread(&c, 1, 1, f)==1)
		CFDataAppendBytes(fileContents, &c, 1);
	
	pclose(f);
	delete[] openCmd;
	delete[] filePath;
	
	return(noErr);
}