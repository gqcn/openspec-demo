import { e as eventHandler, a as useResponseSuccess } from '../../../nitro/nitro.mjs';
import { T as TIME_ZONE_OPTIONS } from '../../../_/mock-data.mjs';
import 'node:http';
import 'node:https';
import 'node:events';
import 'node:buffer';
import 'node:fs';
import 'node:path';
import 'node:crypto';
import 'node:url';

const getTimezoneOptions = eventHandler(() => {
  const data = TIME_ZONE_OPTIONS.map((o) => ({
    label: `${o.timezone} (GMT${o.offset >= 0 ? `+${o.offset}` : o.offset})`,
    value: o.timezone
  }));
  return useResponseSuccess(data);
});

export { getTimezoneOptions as default };
//# sourceMappingURL=getTimezoneOptions.mjs.map
