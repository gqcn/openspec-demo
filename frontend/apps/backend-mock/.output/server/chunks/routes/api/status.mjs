import { e as eventHandler, j as getQuery, s as setResponseStatus, b as useResponseError } from '../../nitro/nitro.mjs';
import 'node:http';
import 'node:https';
import 'node:events';
import 'node:buffer';
import 'node:fs';
import 'node:path';
import 'node:crypto';
import 'node:url';

const status = eventHandler((event) => {
  const { status } = getQuery(event);
  setResponseStatus(event, Number(status));
  return useResponseError(`${status}`);
});

export { status as default };
//# sourceMappingURL=status.mjs.map
