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

// common.h

// This file contains prototypes for functions to perform general purpose
// XML node text extraction and to process the shared meta.xml file format
// that is common to all OOo file types.

// Planamesa, Inc.
// 4/27/05

#ifndef COMMON_H_

#define COMMON_H_

#include <CoreFoundation/CoreFoundation.h>

/**
 * String encoding used for extracting text from OOo zip files
 */
#define kTextExtractionEncoding	    kCFStringEncodingUnicode

/**
 * Character type for the above string encoding
 */
typedef UInt16 TextExtractionCharType;

/**
 * Given a path to a zip archive, extract the content of an individual file
 * of that zip archive into a mutable data structure.
 *
 * The file is attempted to be extracted using UTF8 encoding.
 *
 * @param pathToArhive		path to the zip archive on disk
 * @param fileToExtract		file from the archive that should be extracted
 * @param fileContents		mutable data that should be filled with the
 *				contents of that subfile.    File content
 *				will be appended onto any preexisting data
 *				already in the ref.
 * @return noErr on success, else OS error code
 */
OSErr ExtractZipArchiveContent(CFStringRef pathToArchive, const char *fileToExtract, CFMutableDataRef fileContents);

/**
 * Given the content of a meta.xml document stored in a CFData object, extract
 * relevant metadata into a spotlight dictionary.
 */
void ParseMetaXML(CFMutableDataRef contentCFData, CFMutableDictionaryRef spotlightDict);

/**
 * Given a node of a CoreFoundation XML structure, extracxt any
 * text content from that node or recurse on the node's children as
 * appropriate.
 *
 * The text data is attempted to be extracted with UTF8 encoding, in
 * internal representation (no byte ordering marker)
 *
 * @param elementPrefix	element tag names are examined for this prefix.  When
 *			encountered, all text data child nodes will have their
 *			content concatenated onto the mutable data
 * @param xmlTreeNode	current tree representation of the node being parsed
 * @param textData	when the first element is found with the given prefix,
 *			all of the child text nodes of that element will
 *			have their content appended onto this mutable data
 *			elemnet.
 * @param separatorChar	UTF8 character used to separate consecutive text nodes in
 *			the metadata
 * @param saveText	true to save CFDATA node content as text, FALSE to just
 *			recurse into element children
 */
void ExtractNodeText(CFStringRef elementPrefix, CFXMLTreeRef xmlTreeNode, CFMutableDataRef textData, TextExtractionCharType separatorChar=' ', bool nodeEncountered=false);

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
 */
void ExtractNodeAttributeValue(CFStringRef elementPrefix, CFStringRef attributeName, CFXMLTreeRef xmlTreeNode, CFMutableDataRef textData, TextExtractionCharType separatorChar=' ');

/**
 * Parse a styles.xml file of an OOo formatted file into for spotlight to index
 * header and footer content
 *
 * @param styleCFData		XML file with styles.xml extaction
 * @param spotlightDict		spotlight dictionary to be filled wih the text content
 */
void ParseStylesXML(CFMutableDataRef styleCFData, CFMutableDictionaryRef spotlightDict);

#endif