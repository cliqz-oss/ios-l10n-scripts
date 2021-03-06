#!/usr/bin/env python

#
# xliff-cliqz-cleanup.py <files>
#
#  1. Remove all <file> sections that we do not care about. We only care
#     about the one for our main app and those for our extensions.
#
#  2. Look at all remaining <file> sections and remove those strings that
#     should not be localized. Currently that means: CFBundleDisplayName,
#     CFBundleName and CFBundleShortVersionString.
#
#  3. Copy English in required strings.
#
#  4. Remove all remaining <file> sections that now have no <trans-unit>
#     nodes in their <body> anymore.
#
# Modifies files in place. Makes no backup.
#

import sys

from lxml import etree

NS = {'x':'urn:oasis:names:tc:xliff:document:1.2'}

def indent(elem, level=0):
    # Prettify XML output
    # http://effbot.org/zone/element-lib.htm#prettyprint
    i = '\n' + level*'  '
    if len(elem):
        if not elem.text or not elem.text.strip():
            elem.text = i + '  '
        if not elem.tail or not elem.tail.strip():
            elem.tail = i
        for elem in elem:
            indent(elem, level+1)
        if not elem.tail or not elem.tail.strip():
            elem.tail = i
    else:
        if level and (not elem.tail or not elem.tail.strip()):
            elem.tail = i

files_to_keep = [
    'Client/en.lproj/InfoPlist.strings',
    'Client/en.lproj/Cliqz.strings',
    'Client/en.lproj/Ghostery.strings',
    'Client/en.lproj/Lumen.strings',
    'Extensions/ShareTo/en.lproj/Cliqz.strings',
    'Extensions/Today/en.lproj/Cliqz.strings',
    'Cliqz/Resources/en.lproj/Cliqz.stringsdict'
]

required_ids = [
    'NSCameraUsageDescription',
    'NSLocationWhenInUseUsageDescription',
    'NSMicrophoneUsageDescription',
    'NSPhotoLibraryAddUsageDescription',
    'NSPhotoLibraryUsageDescription',
    'NSFaceIDUsageDescription',
    'ShortcutItemTitleNewPrivateTab',
    'ShortcutItemTitleNewTab',
    'ShortcutItemTitleQRCode',
]

if __name__ == '__main__':
    for path in sys.argv[1:]:
        # Read it in and modify it in memory
        with open(path) as fp:
            try:
                tree = etree.parse(fp)
                root = tree.getroot()
            except Exception as e:
                print("ERROR: Can't parse file %s" % path)
                print(e)
                continue

            # 1. Remove sections we do not care about
            for file_node in root.xpath('//x:file', namespaces=NS):
                file_name = file_node.get('original')
                if file_name not in files_to_keep:
                    file_node.getparent().remove(file_node)
                    

            for trans_node in root.xpath('//x:trans-unit', namespaces=NS):
                file_name = trans_node.getparent().getparent().get('original')
                source_string = trans_node.xpath('./x:source', namespaces=NS)[0].text
                original_id = trans_node.get('id')

                # 2. Copy English in required strings if there's no translation
                if original_id in required_ids and len(trans_node.xpath('./x:target', namespaces=NS)) == 0:
                    child = etree.Element('target')
                    child.text = source_string
                    trans_node.insert(1, child)

            # 3. Remove empty file sections
            for file_node in root.xpath('//x:file', namespaces=NS):
                file_name = file_node.get('original')
                if file_name.endswith('Info.plist'):
                    trans_unit_nodes = file_node.xpath('x:body/x:trans-unit', namespaces=NS)
                    if len(trans_unit_nodes) == 0:
                        file_node.getparent().remove(file_node)
        # Write it back to the same file
        with open(path, 'w') as fp:
            indent(root)
            xliff_content = etree.tostring(
                                tree,
                                encoding='UTF-8',
                                xml_declaration=True,
                                pretty_print=True
                            )
            fp.write(xliff_content)
