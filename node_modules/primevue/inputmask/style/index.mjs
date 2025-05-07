import BaseStyle from '@primevue/core/base/style';

var classes = {
  root: function root(_ref) {
    var instance = _ref.instance;
    return ['p-inputmask', {
      'p-filled': instance.$filled
    }];
  }
};
var InputMaskStyle = BaseStyle.extend({
  name: 'inputmask',
  classes: classes
});

export { InputMaskStyle as default };
//# sourceMappingURL=index.mjs.map
