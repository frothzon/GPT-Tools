from __future__ import annotations

from pathlib import Path


def write_fixture(root: Path) -> Path:
    files = {
        "Fixture.yyp": """{
  \"$GMProject\":\"v1\",
  \"%Name\":\"Fixture\",
  \"AudioGroups\":[{\"name\":\"audiogroup_default\",}],
  \"Folders\":[{\"name\":\"Fixture\",\"folderPath\":\"folders/Fixture.yy\",}],
  \"IncludedFiles\":[],
  \"MetaData\":{\"IDEVersion\":\"2024.14.4.222\",},
  \"name\":\"Fixture\",
  \"resources\":[
    {\"id\":{\"name\":\"scr_math\",\"path\":\"scripts/scr_math/scr_math.yy\",},},
    {\"id\":{\"name\":\"obj_test\",\"path\":\"objects/obj_test/obj_test.yy\",},},
    {\"id\":{\"name\":\"shd_test\",\"path\":\"shaders/shd_test/shd_test.yy\",},},
    {\"id\":{\"name\":\"spr_test\",\"path\":\"sprites/spr_test/spr_test.yy\",},},
  ],
  \"resourceType\":\"GMProject\",
  \"resourceVersion\":\"2.0\",
  \"RoomOrderNodes\":[],
  \"TextureGroups\":[{\"name\":\"Default\",}],
}
""",
        "Fixture.resource_order": """{
  \"FolderOrderSettings\":[],
  \"ResourceOrderSettings\":[
    {\"name\":\"scr_math\",\"order\":1,\"path\":\"scripts/scr_math/scr_math.yy\",},
  ],
}
""",
        "scripts/scr_math/scr_math.yy": """{
  \"$GMScript\":\"v1\",\"%Name\":\"scr_math\",\"isCompatibility\":false,\"isDnD\":false,
  \"name\":\"scr_math\",\"parent\":{\"name\":\"Fixture\",\"path\":\"folders/Fixture.yy\",},
  \"resourceType\":\"GMScript\",\"resourceVersion\":\"2.0\",
}
""",
        "scripts/scr_math/scr_math.gml": "function add(a, b) {\n    return a + b;\n}\n",
        "objects/obj_test/obj_test.yy": """{
  \"$GMObject\":\"\",\"%Name\":\"obj_test\",
  \"eventList\":[{\"$GMEvent\":\"v1\",\"eventNum\":0,\"eventType\":0,\"isDnD\":false,},],
  \"name\":\"obj_test\",\"parent\":{\"name\":\"Fixture\",\"path\":\"folders/Fixture.yy\",},
  \"resourceType\":\"GMObject\",\"resourceVersion\":\"2.0\",
}
""",
        "objects/obj_test/Create_0.gml": "value = add(1, 2);\n",
        "shaders/shd_test/shd_test.yy": """{
  \"$GMShader\":\"\",\"%Name\":\"shd_test\",\"name\":\"shd_test\",
  \"parent\":{\"name\":\"Fixture\",\"path\":\"folders/Fixture.yy\",},
  \"resourceType\":\"GMShader\",\"resourceVersion\":\"2.0\",\"type\":1,
}
""",
        "shaders/shd_test/shd_test.vsh": "void main() { gl_Position = vec4(0.0); }\n",
        "shaders/shd_test/shd_test.fsh": "void main() { gl_FragColor = vec4(1.0); }\n",
        "sprites/spr_test/spr_test.yy": """{
  \"$GMSprite\":\"v2\",\"%Name\":\"spr_test\",\"name\":\"spr_test\",
  \"parent\":{\"name\":\"Fixture\",\"path\":\"folders/Fixture.yy\",},
  \"resourceType\":\"GMSprite\",\"resourceVersion\":\"2.0\",
  \"textureGroupId\":{\"name\":\"Default\",\"path\":\"texturegroups/Default\",},
}
""",
    }
    for relative, content in files.items():
        path = root / Path(relative)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8", newline="")
    return root / "Fixture.yyp"
