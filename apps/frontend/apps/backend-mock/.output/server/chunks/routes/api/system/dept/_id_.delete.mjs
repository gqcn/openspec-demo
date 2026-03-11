import { e as eventHandler, u as unAuthorizedResponse, k as sleep, a as useResponseSuccess } from '../../../../nitro/nitro.mjs';
import { v as verifyAccessToken } from '../../../../_/jwt-utils.mjs';
import 'node:http';
import 'node:https';
import 'node:events';
import 'node:buffer';
import 'node:fs';
import 'node:path';
import 'node:crypto';
import 'node:url';
import 'jsonwebtoken';
import '../../../../_/mock-data.mjs';

const _id__delete = eventHandler(async (event) => {
  const userinfo = verifyAccessToken(event);
  if (!userinfo) {
    return unAuthorizedResponse(event);
  }
  await sleep(1e3);
  return useResponseSuccess(null);
});

export { _id__delete as default };
//# sourceMappingURL=_id_.delete.mjs.map
