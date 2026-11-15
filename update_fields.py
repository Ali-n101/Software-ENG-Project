import zipfile, os
from lxml import etree
p = r'C:\Users\Ali\Desktop\Software_ENG_project\SDD_Template_Students_2026_Updated.docx'
tmp = p + '.tmp'
ns = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
with zipfile.ZipFile(p) as zin, zipfile.ZipFile(tmp, 'w', zipfile.ZIP_DEFLATED) as zout:
    for item in zin.infolist():
        data = zin.read(item.filename)
        if item.filename == 'word/settings.xml':
            root = etree.fromstring(data)
            elem = root.find('w:updateFields', ns)
            if elem is None:
                elem = etree.SubElement(root, '{%s}updateFields' % ns['w'])
            elem.set('{%s}val' % ns['w'], 'true')
            data = etree.tostring(root, xml_declaration=True, encoding='UTF-8', standalone=True)
        zout.writestr(item, data)
os.replace(tmp, p)
print('Set Word to refresh TOC fields when the copy opens.')
