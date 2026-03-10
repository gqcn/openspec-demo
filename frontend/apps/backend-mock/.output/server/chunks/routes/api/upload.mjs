import { e as eventHandler, u as unAuthorizedResponse, a as useResponseSuccess } from '../../nitro/nitro.mjs';
import { v as verifyAccessToken } from '../../_/jwt-utils.mjs';
import 'node:http';
import 'node:https';
import 'node:events';
import 'node:buffer';
import 'node:fs';
import 'node:path';
import 'node:crypto';
import 'node:url';
import 'jsonwebtoken';
import '../../_/mock-data.mjs';

const upload = eventHandler((event) => {
  const userinfo = verifyAccessToken(event);
  if (!userinfo) {
    return unAuthorizedResponse(event);
  }
  return useResponseSuccess({
    url: "https://unpkg.com/@vbenjs/static-source@0.1.7/source/logo-v1.webp"
  });
});

export { upload as default };
//# sourceMappingURL=upload.mjs.map
