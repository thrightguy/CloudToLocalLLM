import { style } from '@primeuix/styles/editor';
import BaseStyle from '@primevue/core/base/style';

var classes = {
  root: function root(_ref) {
    var instance = _ref.instance;
    return ['p-editor', {
      'p-invalid': instance.$invalid
    }];
  },
  toolbar: 'p-editor-toolbar',
  content: 'p-editor-content'
};
var EditorStyle = BaseStyle.extend({
  name: 'editor',
  style: style,
  classes: classes
});

export { EditorStyle as default };
//# sourceMappingURL=index.mjs.map
