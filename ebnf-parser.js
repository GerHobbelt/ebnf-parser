var bnf = require("./parser").parser,
    ebnf = require("./ebnf-transform"),
    jisonlex = require("lex-parser");

exports.parse = function parse (grammar) { return bnf.parse(grammar); };
exports.transform = ebnf.transform;

// adds a declaration to the grammar
bnf.yy.addDeclaration = function (grammar, decl) {
    if (decl.start) {
        grammar.start = decl.start;

    } else if (decl.lex) {
        grammar.lex = parseLex(decl.lex);

    } else if (decl.operator) {
        if (!grammar.operators) grammar.operators = [];
        grammar.operators.push(decl.operator);

    } else if (decl.token) {
        if (!grammar.extra_tokens) grammar.extra_tokens = [];
        grammar.extra_tokens.push(decl.token);

    } else if (decl.parseParam) {
        if (!grammar.parseParams) grammar.parseParams = [];
        grammar.parseParams = grammar.parseParams.concat(decl.parseParam);

    } else if (decl.include) {
        if (!grammar.moduleInclude) grammar.moduleInclude = '';
        grammar.moduleInclude += decl.include;

    } else if (decl.options) {
        if (!grammar.options) grammar.options = {};
        for (var i=0; i < decl.options.length; i++) {
            grammar.options[decl.options[i]] = true;
        }
    }
    else if (decl.actionInclude) {
        if (!grammar.actionInclude)
            grammar.actionInclude = '';
        grammar.actionInclude += decl.actionInclude;
    }
};

// parse an embedded lex section
var parseLex = function (text) {
    return jisonlex.parse(text.replace(/(?:^%lex)|(?:\/lex$)/g, ''));
};

