(function () {
    'use strict';

    var supportsAnnotation = !!(window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.annotation);

    if (!supportsAnnotation) {
        return;
    }

    var DEFAULT_STRINGS = {
        addAnnotation: 'Add annotation',
        cancel: 'Cancel',
        ok: 'Ok',
        placeholder: 'Add a note...',
        edit: 'Edit',
        delete: 'Delete'
    };

    function getStrings() {
        return window.__annotationStrings || DEFAULT_STRINGS;
    }

    var tooltip = null;
    var viewerTooltip = null;
    var currentSelection = null;
    var highlightSpan = null;
    var displayed = false;
    var annotationsById = {};
    var editingId = null;
    var activeHighlight = null;

    function createTooltip() {
        var tip = document.createElement('div');
        tip.className = 'wallino-annotation-tooltip';

        var textarea = document.createElement('textarea');
        textarea.rows = 3;
        textarea.placeholder = getStrings().placeholder;

        var cancelBtn = document.createElement('button');
        cancelBtn.type = 'button';
        cancelBtn.className = 'wallino-annotation-cancel';
        cancelBtn.textContent = getStrings().cancel;

        var okBtn = document.createElement('button');
        okBtn.type = 'button';
        okBtn.className = 'wallino-annotation-ok';
        okBtn.textContent = getStrings().ok;

        cancelBtn.addEventListener('click', function (e) {
            e.preventDefault();
            e.stopPropagation();
            onCancel();
        });

        okBtn.addEventListener('click', function (e) {
            e.preventDefault();
            e.stopPropagation();
            onOk(textarea.value.trim());
        });

        var actions = document.createElement('div');
        actions.className = 'wallino-annotation-actions';
        actions.appendChild(cancelBtn);
        actions.appendChild(okBtn);

        tip.appendChild(textarea);
        tip.appendChild(actions);
        document.body.appendChild(tip);
        return tip;
    }

    function createViewerTooltip() {
        var tip = document.createElement('div');
        tip.className = 'wallino-annotation-viewer';

        var header = document.createElement('div');
        header.className = 'wallino-annotation-viewer-header';

        var editBtn = document.createElement('button');
        editBtn.type = 'button';
        editBtn.className = 'wallino-annotation-edit';
        editBtn.textContent = '\u270E';
        editBtn.setAttribute('aria-label', getStrings().edit);

        var deleteBtn = document.createElement('button');
        deleteBtn.type = 'button';
        deleteBtn.className = 'wallino-annotation-delete';
        deleteBtn.textContent = '\u2715';
        deleteBtn.setAttribute('aria-label', getStrings().delete);

        editBtn.addEventListener('click', function (e) {
            e.preventDefault();
            e.stopPropagation();
            onEdit();
        });

        deleteBtn.addEventListener('click', function (e) {
            e.preventDefault();
            e.stopPropagation();
            onDelete();
        });

        header.appendChild(editBtn);
        header.appendChild(deleteBtn);

        var text = document.createElement('div');
        text.className = 'wallino-annotation-viewer-text';

        tip.appendChild(header);
        tip.appendChild(text);
        document.body.appendChild(tip);
        return tip;
    }

    function ensureTooltip() {
        if (!tooltip) {
            tooltip = createTooltip();
        }
    }

    function ensureViewerTooltip() {
        if (!viewerTooltip) {
            viewerTooltip = createViewerTooltip();
        }
    }

    function tooltipVisible() {
        return !!(tooltip && tooltip.classList.contains('visible'));
    }

    function viewerVisible() {
        return !!(viewerTooltip && viewerTooltip.classList.contains('visible'));
    }

    function getArticleElement() {
        return document.querySelector('article');
    }

    function elementXPath(element, root) {
        if (!element || element.nodeType !== Node.ELEMENT_NODE) {
            return '';
        }
        var parts = [];
        var current = element;
        while (current && current.nodeType === Node.ELEMENT_NODE && current !== root) {
            var index = 1;
            var sibling = current.previousElementSibling;
            while (sibling) {
                if (sibling.tagName === current.tagName) {
                    index++;
                }
                sibling = sibling.previousElementSibling;
            }
            parts.unshift(current.tagName.toLowerCase() + '[' + index + ']');
            current = current.parentElement;
        }
        return '/' + parts.join('/');
    }

    function getContentParent(node) {
        var parent = node ? node.parentNode : null;
        while (parent && parent.nodeType === Node.ELEMENT_NODE && parent.classList && parent.classList.contains('wallino-annotation-highlight')) {
            parent = parent.parentNode;
        }
        return parent;
    }

    function getTextNodes(element) {
        var nodes = [];
        var walker = document.createTreeWalker(element, 4 /* NodeFilter.SHOW_TEXT */);
        var node;
        while ((node = walker.nextNode())) {
            nodes.push(node);
        }
        return nodes;
    }

    function getFirstTextNodeNotBefore(node) {
        if (!node) {
            return null;
        }
        if (node.nodeType === Node.TEXT_NODE) {
            return node;
        }
        if (node.nodeType === Node.ELEMENT_NODE && node.firstChild) {
            var result = getFirstTextNodeNotBefore(node.firstChild);
            if (result) {
                return result;
            }
        }
        return getFirstTextNodeNotBefore(node.nextSibling);
    }

    function getLastTextNodeUpTo(node) {
        if (!node) {
            return null;
        }
        if (node.nodeType === Node.TEXT_NODE) {
            return node;
        }
        if (node.nodeType === Node.ELEMENT_NODE && node.lastChild) {
            var result = getLastTextNodeUpTo(node.lastChild);
            if (result) {
                return result;
            }
        }
        return getLastTextNodeUpTo(node.previousSibling);
    }

    function normalizeStart(container, offset) {
        if (container.nodeType === Node.TEXT_NODE) {
            return { node: container, offset: offset };
        }
        var node = getFirstTextNodeNotBefore(container.childNodes[offset]);
        return { node: node, offset: 0 };
    }

    function normalizeEnd(container, offset) {
        if (container.nodeType === Node.TEXT_NODE) {
            return { node: container, offset: offset };
        }
        var child = offset ? container.childNodes[offset - 1] : container.previousSibling;
        var node = getLastTextNodeUpTo(child);
        return { node: node, offset: node ? node.nodeValue.length : 0 };
    }

    function textOffsetWithin(element, textNode, localOffset) {
        if (!textNode) {
            return 0;
        }
        var offset = 0;
        var nodes = getTextNodes(element);
        for (var i = 0; i < nodes.length; i++) {
            if (nodes[i] === textNode) {
                return offset + localOffset;
            }
            offset += nodes[i].nodeValue.length;
        }
        return offset + localOffset;
    }

    function serializeRange(range) {
        var root = getArticleElement();
        var start = normalizeStart(range.startContainer, range.startOffset);
        var end = normalizeEnd(range.endContainer, range.endOffset);

        var startParent = getContentParent(start.node);
        var endParent = getContentParent(end.node);

        return {
            start: startParent ? elementXPath(startParent, root) : '',
            startOffset: textOffsetWithin(startParent, start.node, start.offset),
            end: endParent ? elementXPath(endParent, root) : '',
            endOffset: textOffsetWithin(endParent, end.node, end.offset)
        };
    }

    function resolveNode(xpath) {
        if (!xpath) {
            return null;
        }
        var root = getArticleElement();
        if (!root) {
            return null;
        }
        var result = document.evaluate('.' + xpath, root, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null);
        return result.singleNodeValue;
    }

    function resolveBoundary(element, offset, isEnd) {
        var targetOffset = isEnd ? offset - 1 : offset;
        var length = 0;
        var walker = document.createTreeWalker(element, 4 /* NodeFilter.SHOW_TEXT */);
        var node;
        while ((node = walker.nextNode())) {
            if (length + node.nodeValue.length > targetOffset) {
                return { node: node, offset: offset - length };
            }
            length += node.nodeValue.length;
        }
        return null;
    }

    function resolveRange(data) {
        var startElement = resolveNode(data.start);
        var endElement = resolveNode(data.end);
        if (!startElement || !endElement) {
            return null;
        }

        var start = resolveBoundary(startElement, data.startOffset, false);
        var end = resolveBoundary(endElement, data.endOffset, true);
        if (!start || !end) {
            return null;
        }

        var range = document.createRange();
        range.setStart(start.node, start.offset);
        range.setEnd(end.node, end.offset);
        return range;
    }

    function highlightRange(range, annotationId) {
        var span = document.createElement('span');
        span.className = 'wallino-annotation-highlight';
        span.setAttribute('data-annotation-id', annotationId);
        var fragment = range.extractContents();
        span.appendChild(fragment);
        range.insertNode(span);
    }

    function displayAnnotations(annotations) {
        if (displayed) {
            return;
        }
        displayed = true;
        if (!annotations || !annotations.length) {
            return;
        }
        var items = [];
        for (var i = 0; i < annotations.length; i++) {
            var annotation = annotations[i];
            annotationsById[annotation.id] = annotation.text || '';
            var ranges = annotation.ranges || [];
            if (!ranges.length) {
                continue;
            }
            var range = resolveRange(ranges[0]);
            if (range) {
                items.push({ range: range, id: annotation.id });
            }
        }
        items.sort(function (a, b) {
            return a.range.compareBoundaryPoints(Range.START_TO_START, b.range);
        });
        for (var j = items.length - 1; j >= 0; j--) {
            highlightRange(items[j].range, items[j].id);
        }
    }

    function getSelectionData() {
        var selection = window.getSelection();
        if (!selection || selection.isCollapsed || selection.rangeCount === 0) {
            return null;
        }
        var range = selection.getRangeAt(0);
        var quote = selection.toString();
        if (!quote || quote.trim().length === 0) {
            return null;
        }
        var article = document.getElementById('article');
        if (article && !article.contains(range.commonAncestorContainer)) {
            return null;
        }
        return {
            range: range,
            ranges: [serializeRange(range)],
            quote: quote
        };
    }

    function highlightSelection(range) {
        highlightSpan = document.createElement('span');
        highlightSpan.className = 'wallino-annotation-highlight';
        var fragment = range.extractContents();
        highlightSpan.appendChild(fragment);
        range.insertNode(highlightSpan);
    }

    function viewportHeight() {
        if (window.visualViewport && window.visualViewport.height) {
            return window.visualViewport.height;
        }
        return window.innerHeight;
    }

    function positionElement(element, ref) {
        element.style.left = '8px';
        element.style.width = (window.innerWidth - 16) + 'px';
        var height = viewportHeight();
        var top;
        if (!ref) {
            top = 8;
        } else {
            var rect = ref.getBoundingClientRect();
            top = rect.bottom + 8;
            if (top + element.offsetHeight > height) {
                top = rect.top - element.offsetHeight - 8;
            }
        }
        top = Math.max(8, Math.min(top, height - element.offsetHeight - 8));
        element.style.top = top + 'px';
    }

    function repositionVisibleTooltip() {
        if (tooltipVisible()) {
            positionElement(tooltip, editingId != null ? activeHighlight : highlightSpan);
        } else if (viewerVisible()) {
            positionElement(viewerTooltip, activeHighlight);
        }
    }

    function showEditor(text) {
        ensureTooltip();
        var textarea = tooltip.querySelector('textarea');
        textarea.value = text || '';
        positionElement(tooltip, editingId != null ? activeHighlight : highlightSpan);
        tooltip.classList.add('visible');
        textarea.focus();
    }

    function annotateSelection() {
        var data = getSelectionData() || currentSelection;
        if (!data || !data.range || tooltipVisible() || viewerVisible()) {
            return;
        }
        currentSelection = data;
        editingId = null;
        activeHighlight = null;
        highlightSelection(data.range);
        showEditor('');
    }

    function onCancel() {
        if (editingId == null) {
            unwrapSpan(highlightSpan);
            highlightSpan = null;
        }
        editingId = null;
        closeTooltip();
        currentSelection = null;
        activeHighlight = null;
    }

    function unwrapSpan(span) {
        if (!span) {
            return;
        }
        var parent = span.parentNode;
        if (!parent) {
            return;
        }
        while (span.firstChild) {
            parent.insertBefore(span.firstChild, span);
        }
        parent.removeChild(span);
    }

    function removeHighlightById(id) {
        var selector = '.wallino-annotation-highlight[data-annotation-id="' + id + '"]';
        var spans = document.querySelectorAll(selector);
        for (var i = 0; i < spans.length; i++) {
            unwrapSpan(spans[i]);
        }
        delete annotationsById[id];
    }

    function closeTooltip() {
        if (!tooltip) {
            return;
        }
        tooltip.classList.remove('visible');
        tooltip.querySelector('textarea').value = '';
    }

    function closeViewer() {
        if (!viewerTooltip) {
            return;
        }
        viewerTooltip.classList.remove('visible');
        activeHighlight = null;
    }

    function onOk(text) {
        if (editingId != null) {
            annotationsById[editingId] = text;
            window.webkit.messageHandlers.annotation.postMessage({ type: 'update', id: editingId, text: text });
            editingId = null;
        } else if (currentSelection) {
            window.webkit.messageHandlers.annotation.postMessage({
                type: 'add',
                text: text,
                quote: currentSelection.quote,
                ranges: currentSelection.ranges
            });
            currentSelection = null;
        }
        closeTooltip();
        activeHighlight = null;
    }

    function onSelectionChange() {
        var data = getSelectionData();
        if (data) {
            currentSelection = data;
        }
    }

    function onDocumentClick(e) {
        if (tooltipVisible()) {
            return;
        }
        var target = e.target;
        var span = target.closest ? target.closest('.wallino-annotation-highlight') : null;
        if (span && span.getAttribute('data-annotation-id')) {
            e.preventDefault();
            e.stopPropagation();
            onHighlightTap(span);
            return;
        }
        if (viewerVisible()) {
            closeViewer();
        }
    }

    function onHighlightTap(span) {
        var id = parseInt(span.getAttribute('data-annotation-id'), 10);
        if (isNaN(id)) {
            return;
        }
        activeHighlight = span;
        ensureViewerTooltip();
        viewerTooltip.querySelector('.wallino-annotation-viewer-text').textContent = annotationsById[id] || '';
        viewerTooltip.setAttribute('data-annotation-id', String(id));
        positionElement(viewerTooltip, span);
        viewerTooltip.classList.add('visible');
    }

    function onEdit() {
        var id = parseInt(viewerTooltip.getAttribute('data-annotation-id'), 10);
        if (isNaN(id)) {
            return;
        }
        viewerTooltip.classList.remove('visible');
        editingId = id;
        showEditor(annotationsById[id] || '');
    }

    function onDelete() {
        var id = parseInt(viewerTooltip.getAttribute('data-annotation-id'), 10);
        if (isNaN(id)) {
            return;
        }
        closeViewer();
        removeHighlightById(id);
        window.webkit.messageHandlers.annotation.postMessage({ type: 'delete', id: id });
    }

    function onAnnotationAdded(id, text) {
        if (highlightSpan) {
            highlightSpan.setAttribute('data-annotation-id', String(id));
        }
        annotationsById[id] = text;
        highlightSpan = null;
    }

    function init() {
        document.addEventListener('selectionchange', onSelectionChange);
        document.addEventListener('click', onDocumentClick);
        if (window.visualViewport) {
            window.visualViewport.addEventListener('resize', repositionVisibleTooltip);
        }
    }

    window.__wallinoAnnotateSelection = annotateSelection;
    window.__wallinoDisplayAnnotations = displayAnnotations;
    window.__wallinoOnAnnotationAdded = onAnnotationAdded;

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();
