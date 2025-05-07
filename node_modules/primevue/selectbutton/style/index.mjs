import { style } from '@primeuix/styles/selectbutton';
import BaseStyle from '@primevue/core/base/style';

var classes = {
  root: function root(_ref) {
    var instance = _ref.instance;
    return ['p-selectbutton p-component', {
      'p-invalid': instance.$invalid // @todo: check
    }];
  }
};
var SelectButtonStyle = BaseStyle.extend({
  name: 'selectbutton',
  style: style,
  classes: classes
});

export { SelectButtonStyle as default };
//# sourceMappingURL=index.mjs.map
