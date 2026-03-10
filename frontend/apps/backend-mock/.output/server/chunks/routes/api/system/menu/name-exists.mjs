import { e as eventHandler, u as unAuthorizedResponse, j as getQuery, a as useResponseSuccess } from '../../../../nitro/nitro.mjs';
import { v as verifyAccessToken } from '../../../../_/jwt-utils.mjs';
import { c as MOCK_MENU_LIST } from '../../../../_/mock-data.mjs';
import 'node:http';
import 'node:https';
import 'node:events';
import 'node:buffer';
import 'node:fs';
import 'node:path';
import 'node:crypto';
import 'node:url';
import 'jsonwebtoken';

const namesMap = {};
function getNames(menus) {
  menus.forEach((menu) => {
    namesMap[menu.name] = String(menu.id);
    if (menu.children) {
      getNames(menu.children);
    }
  });
}
getNames(MOCK_MENU_LIST);
const nameExists = eventHandler(async (event) => {
  const userinfo = verifyAccessToken(event);
  if (!userinfo) {
    return unAuthorizedResponse(event);
  }
  const { id, name } = getQuery(event);
  return name in namesMap && (!id || namesMap[name] !== String(id)) ? useResponseSuccess(true) : useResponseSuccess(false);
});

export { nameExists as default };
//# sourceMappingURL=name-exists.mjs.map
