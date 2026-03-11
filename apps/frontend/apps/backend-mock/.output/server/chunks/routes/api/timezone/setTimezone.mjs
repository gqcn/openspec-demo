import { e as eventHandler, u as unAuthorizedResponse, r as readBody, s as setResponseStatus, b as useResponseError, a as useResponseSuccess } from '../../../nitro/nitro.mjs';
import { v as verifyAccessToken } from '../../../_/jwt-utils.mjs';
import { T as TIME_ZONE_OPTIONS } from '../../../_/mock-data.mjs';
import { s as setTimezone$1 } from '../../../_/timezone-utils.mjs';
import 'node:http';
import 'node:https';
import 'node:events';
import 'node:buffer';
import 'node:fs';
import 'node:path';
import 'node:crypto';
import 'node:url';
import 'jsonwebtoken';

const setTimezone = eventHandler(async (event) => {
  const userinfo = verifyAccessToken(event);
  if (!userinfo) {
    return unAuthorizedResponse(event);
  }
  const body = await readBody(event);
  const timezone = typeof (body == null ? void 0 : body.timezone) === "string" ? body.timezone : void 0;
  const allowed = TIME_ZONE_OPTIONS.some((o) => o.timezone === timezone);
  if (!timezone || !allowed) {
    setResponseStatus(event, 400);
    return useResponseError("Bad Request", "Invalid timezone");
  }
  setTimezone$1(timezone);
  return useResponseSuccess({});
});

export { setTimezone as default };
//# sourceMappingURL=setTimezone.mjs.map
