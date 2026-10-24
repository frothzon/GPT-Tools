import re
import urllib.request
request = urllib.request.Request("https://manual.gamemaker.io/monthly/en/Content.htm", headers={"User-Agent": "Mozilla/5.0"})
text = urllib.request.urlopen(request, timeout=20).read().decode()
print(re.findall(r'<script[^>]+src=["\x27]([^"\x27]+)', text))
for relative in ('whxdata/toc.js', 'whxdata/toc0.js', 'whxdata/projectsettings.js', 'sitemap.xml', 'GameMaker_Language/GML_Reference/GML_Reference.htm'):
    try:
        request = urllib.request.Request('https://manual.gamemaker.io/monthly/en/' + relative, headers={'User-Agent':'Mozilla/5.0'})
        result = urllib.request.urlopen(request, timeout=20).read().decode()
        print(relative, len(result), result[:900])
    except Exception as error:
        print(relative, str(error))
