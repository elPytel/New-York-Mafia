#!/usr/bin/env python3
"""Merge multiple cards/*.xml files into a single cards XML.

Usage: tools/merge_cards.py <cards_dir> [<cards_dir> ...] <output.xml>
If output omitted, writes to merged-cards.xml in CWD.

This script accepts one or more source directories. Files are merged
in the given order which allows merging a base set (e.g. `cards/base_game`)
followed by one or more DLC directories so DLC cards override or append.
"""
import sys
import os
from xml.etree import ElementTree as ET
import copy


def merge(cards_dirs, out_path):
    # cards_dirs may be a single string or a list of directories
    if isinstance(cards_dirs, (str,)):
        cards_dirs = [cards_dirs]

    files = []
    for cards_dir in cards_dirs:
        if not os.path.isdir(cards_dir):
            continue
        dir_files = sorted(
            [os.path.join(cards_dir, f) for f in os.listdir(cards_dir) if f.endswith('.xml')]
        )
        files.extend(dir_files)

    if not files:
        raise SystemExit('No XML files found in %s' % (', '.join(cards_dirs)))

    first = True
    root = ET.Element('cards')

    for fn in files:
        try:
            tree = ET.parse(fn)
        except ET.ParseError as e:
            raise SystemExit('Failed to parse %s: %s' % (fn, e))
        src = tree.getroot()
        # copy game/version from first file if present
        if first:
            for attr in ('game', 'version'):
                if attr in src.attrib:
                    root.set(attr, src.attrib[attr])
        # Do NOT copy `icons` from individual source files here.
        # Icons are collected from canonical config files below to avoid
        # duplicating the same icons block when sources include their own
        # `<icons>` or use XIncludes. We only merge card elements from sources.

        for card in src.findall('card'):
            # deep copy element
            root.append(card)

        first = False

    tree = ET.ElementTree(root)
    ET.indent(tree, space='  ')
    # also include icons from nearby config/icons.xml files (merge if icons already present)
    icons_candidates = []
    # repo-level config/icons.xml
    icons_candidates.append(os.path.normpath(os.path.join(os.path.dirname(__file__), '..', 'config', 'icons.xml')))
    # common location under cards/config/icons.xml
    icons_candidates.append(os.path.normpath(os.path.join(os.path.dirname(__file__), '..', 'cards', 'config', 'icons.xml')))
    # also check per-source dirs for a sibling ../config/icons.xml (covers cards/DLC/injuries.xml -> cards/config/icons.xml)
    for cds in cards_dirs:
        # if cds is like 'cards/DLC' then parent is 'cards'
        parent = os.path.normpath(os.path.join(cds, '..'))
        icons_candidates.append(os.path.normpath(os.path.join(parent, 'config', 'icons.xml')))

    seen = set()
    for icons_path in icons_candidates:
        if not icons_path or icons_path in seen:
            continue
        seen.add(icons_path)
        if not os.path.exists(icons_path):
            continue
        try:
            icons_tree = ET.parse(icons_path)
        except ET.ParseError as e:
            raise SystemExit('Failed to parse icons file %s: %s' % (icons_path, e))
        icons_src = icons_tree.getroot()
        # config file may be <icons> or have <icons> child
        config_icons = icons_src if icons_src.tag == 'icons' else icons_src.find('icons')
        if config_icons is not None:
            existing_icons = root.find('icons')
            if existing_icons is None:
                # ensure icons are inserted before any card elements
                root.insert(0, copy.deepcopy(config_icons))
            else:
                # append children but avoid duplicates by (tag,name) when possible
                seen_children = set()
                for c in existing_icons:
                    name = c.attrib.get('name')
                    seen_children.add((c.tag, name))
                for child in list(config_icons):
                    key = (child.tag, child.attrib.get('name'))
                    if key in seen_children:
                        continue
                    existing_icons.append(copy.deepcopy(child))
                    seen_children.add(key)

    # ensure icons element is the first child if present
    existing_icons = root.find('icons')
    if existing_icons is not None:
        # if not already first, move it to the front
        try:
            if root[0] is not existing_icons:
                root.remove(existing_icons)
                root.insert(0, existing_icons)
        except IndexError:
            # root is empty or other unexpected state — ignore
            pass
    # ensure output directory exists
    out_dir = os.path.dirname(out_path)
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)
    tree.write(out_path, encoding='utf-8', xml_declaration=True)


def main(argv):
    # Expect at least: <src_dir> <out.xml>
    if len(argv) < 2:
        print(__doc__)
        return 2
    # All arguments except the last are source directories
    src_dirs = argv[:-1]
    out_path = argv[-1]
    merge(src_dirs, out_path)
    print('Wrote', out_path)


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
