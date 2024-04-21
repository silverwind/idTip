import {parse} from "luaparse";
import {readFileSync} from "node:fs";

test("parses", () => {
  const lua = readFileSync(new URL("idTip.lua", import.meta.url), "utf8");
  expect(parse(lua)).toBeTruthy();
});
