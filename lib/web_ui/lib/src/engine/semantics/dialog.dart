// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../dom.dart';
import '../semantics.dart';
import '../util.dart';

/// Provides accessibility for routes, including dialogs and pop-up menus.
class SemanticDialog extends SemanticRole {
  SemanticDialog(SemanticsObject semanticsObject) : super.blank(SemanticRoleKind.dialog, semanticsObject) {
    // The following behaviors can coexist with dialog. Generic `RouteName`
    // and `LabelAndValue` are not used by this role because when the dialog
    // names its own route an `aria-label` is used instead of `aria-describedby`.
    addFocusManagement();
    addLiveRegion();

    // When a route/dialog shows up it is expected that the screen reader will
    // focus on something inside it. There could be two possibilities:
    //
    // 1. The framework explicitly marked a node inside the dialog as focused
    //    via the `isFocusable` and `isFocused` flags. In this case, the node
    //    will request focus directly and there's nothing to do on top of that.
    // 2. No node inside the route takes focus explicitly. In this case, the
    //    expectation is to look through all nodes in traversal order and focus
    //    on the first one.
    semanticsObject.owner.addOneTimePostUpdateCallback(() {
      if (semanticsObject.owner.hasNodeRequestingFocus) {
        // Case 1: a node requested explicit focus. Nothing extra to do.
        return;
      }

      // Case 2: nothing requested explicit focus. Focus on the first descendant.
      _setDefaultFocus();
    });
  }

  void _setDefaultFocus() {
    semanticsObject.visitDepthFirstInTraversalOrder((SemanticsObject node) {
      final SemanticRole? role = node.semanticRole;
      if (role == null) {
        return true;
      }

      // If the node does not take focus (e.g. focusing on it does not make
      // sense at all). Despair not. Keep looking.
      final bool didTakeFocus = role.focusAsRouteDefault();
      return !didTakeFocus;
    });
  }

  @override
  void update() {
    super.update();

    // If semantic object corresponding to the dialog also provides the label
    // for itself it is applied as `aria-label`. See also [describeBy].
    if (semanticsObject.namesRoute) {
      final String? label = semanticsObject.label;
      assert(() {
        if (label == null || label.trim().isEmpty) {
          printWarning(
            'Semantic node ${semanticsObject.id} had both scopesRoute and '
            'namesRoute set, indicating a self-labelled dialog, but it is '
            'missing the label. A dialog should be labelled either by setting '
            'namesRoute on itself and providing a label, or by containing a '
            'child node with namesRoute that can describe it with its content.'
          );
        }
        return true;
      }());
      setAttribute('aria-label', label ?? '');
      setAriaRole('dialog');
    }
  }

  /// Sets the description of this dialog based on a [RouteName] descendant
  /// node, unless the dialog provides its own label.
  void describeBy(RouteName routeName) {
    if (semanticsObject.namesRoute) {
      // The dialog provides its own label, which takes precedence.
      return;
    }

    setAriaRole('dialog');
    setAttribute(
      'aria-describedby',
      routeName.semanticsObject.element.id,
    );
  }

  @override
  bool focusAsRouteDefault() {
    // Dialogs are the ones that look inside themselves to find elements to
    // focus on. It doesn't make sense to focus on the dialog itself.
    return false;
  }
}

/// Supplies a description for the nearest ancestor [SemanticDialog].
///
/// This role is assigned to nodes that have `namesRoute` set but not
/// `scopesRoute`. When both flags are set the node only gets the [SemanticDialog] role.
///
/// If the ancestor dialog is missing, this role has no effect. It is up to the
/// framework, widget, and app authors to make sure a route name is scoped under
/// a route.
class RouteName extends SemanticBehavior {
  RouteName(super.semanticsObject, super.owner);

  SemanticDialog? _dialog;

  @override
  void update() {
    // NOTE(yjbanov): this does not handle the case when the node structure
    // changes such that this RouteName is no longer attached to the same
    // dialog. While this is technically expressible using the semantics API,
    // after discussing this case with customers I decided that this case is not
    // interesting enough to support. A tree restructure like this is likely to
    // confuse screen readers, and it would add complexity to the engine's
    // semantics code. Since reparenting can be done with no update to either
    // the Dialog or RouteName we'd have to scan intermediate nodes for
    // structural changes.
    if (!semanticsObject.namesRoute) {
      return;
    }

    if (semanticsObject.isLabelDirty) {
      final SemanticDialog? dialog = _dialog;
      if (dialog != null) {
        // Already attached to a dialog, just update the description.
        dialog.describeBy(this);
      } else {
        // Setting the label for the first time. Wait for the DOM tree to be
        // established, then find the nearest dialog and update its label.
        semanticsObject.owner.addOneTimePostUpdateCallback(() {
          if (!isDisposed) {
            _lookUpNearestAncestorDialog();
            _dialog?.describeBy(this);
          }
        });
      }
    }
  }

  void _lookUpNearestAncestorDialog() {
    SemanticsObject? parent = semanticsObject.parent;
    while (parent != null && parent.semanticRole?.kind != SemanticRoleKind.dialog) {
      parent = parent.parent;
    }
    if (parent != null && parent.semanticRole?.kind == SemanticRoleKind.dialog) {
      _dialog = parent.semanticRole! as SemanticDialog;
    }
  }
}
