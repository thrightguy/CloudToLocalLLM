import { $dt } from '@primeuix/styled';
import * as utils from '@primeuix/utils';

function blockBodyScroll() {
  utils.blockBodyScroll({
    variableName: $dt('scrollbar.width').name
  });
}
function unblockBodyScroll() {
  utils.unblockBodyScroll({
    variableName: $dt('scrollbar.width').name
  });
}

export { blockBodyScroll, unblockBodyScroll };
//# sourceMappingURL=index.mjs.map
