/* -*- Mode: C++; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/*
 * This file is part of the LibreOffice project.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * This file incorporates work covered by the following license notice:
 *
 *   Licensed to the Apache Software Foundation (ASF) under one or more
 *   contributor license agreements. See the NOTICE file distributed
 *   with this work for additional information regarding copyright
 *   ownership. The ASF licenses this file to you under the Apache
 *   License, Version 2.0 (the "License"); you may not use this file
 *   except in compliance with the License. You may obtain a copy of
 *   the License at http://www.apache.org/licenses/LICENSE-2.0 .
 */

// impress.h

// Function prototyeps for parsing OOo calc "SXI" formatted files.

// Planamesa, Inc.
// 4/27/05

#ifndef IMPRESS_H
#define IMPRESS_H

#import <Foundation/Foundation.h>

// Parse impress presentation files into a Spotlight importer dictionary.
// Will also work for draw files that have embedded text objects.
OSErr ExtractImpressMetadata(CFStringRef pathToFile, CFMutableDictionaryRef spotlightDict);

#endif
