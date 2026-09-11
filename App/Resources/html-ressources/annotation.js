(function () {
    'use strict';

    var supportsAnnotation = !!(window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.annotation);

    if (!supportsAnnotation) {
        return;
    }

    var currentSelection = null;
    var highlightSpan = null;
    var displayed = false;
    var annotationsById = {};

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

    function annotateSelection() {
        var data = getSelectionData() || currentSelection;
        if (!data || !data.range) {
            return;
        }
        currentSelection = data;
        highlightSelection(data.range);
        window.webkit.messageHandlers.annotation.postMessage({
            type: 'showAdd',
            quote: data.quote,
            ranges: data.ranges
        });
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

    function removeAnnotation(id) {
        removeHighlightById(id);
    }

    function openEditor(span) {
        var id = parseInt(span.getAttribute('data-annotation-id'), 10);
        if (isNaN(id)) {
            return;
        }
        var text = annotationsById[id] || '';
        var quote = span.textContent || '';
        window.webkit.messageHandlers.annotation.postMessage({ type: 'showEdit', id: id, text: text, quote: quote });
    }

    function onSelectionChange() {
        var data = getSelectionData();
        if (data) {
            currentSelection = data;
        }
    }

    function onDocumentClick(e) {
        var target = e.target;
        var span = target.closest ? target.closest('.wallino-annotation-highlight') : null;
        if (span && span.getAttribute('data-annotation-id')) {
            e.preventDefault();
            e.stopPropagation();
            openEditor(span);
        }
    }

    function onAnnotationAdded(id, text) {
        if (highlightSpan) {
            highlightSpan.setAttribute('data-annotation-id', String(id));
        }
        annotationsById[id] = text;
        highlightSpan = null;
    }

    function onAnnotationUpdated(id, text) {
        annotationsById[id] = text;
    }

    function onAnnotationAddCancelled() {
        unwrapSpan(highlightSpan);
        highlightSpan = null;
        currentSelection = null;
    }

    function init() {
        document.addEventListener('selectionchange', onSelectionChange);
        document.addEventListener('click', onDocumentClick);
    }

    window.__wallinoAnnotateSelection = annotateSelection;
    window.__wallinoDisplayAnnotations = displayAnnotations;
    window.__wallinoOnAnnotationAdded = onAnnotationAdded;
    window.__wallinoOnAnnotationUpdated = onAnnotationUpdated;
    window.__wallinoOnAnnotationAddCancelled = onAnnotationAddCancelled;
    window.__wallinoRemoveAnnotation = removeAnnotation;

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();
