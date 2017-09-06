%start spec

// %parse-param options


/* grammar for parsing jison grammar files */

%{
var fs = require('fs');
var transform = require('./ebnf-transform').transform;
var ebnf = false;
var XRegExp = require('@gerhobbelt/xregexp');       // for helping out the `%options xregexp` in the lexer
%}


%code error_recovery_reduction %{
    // Note:
    //
    // This code section is specifically targetting error recovery handling in the
    // generated parser when the error recovery is unwinding the parse stack to arrive
    // at the targeted error handling production rule.
    //
    // This code is treated like any production rule action code chunk:
    // Special variables `$$`, `$@`, etc. are recognized, while the 'rule terms' can be
    // addressed via `$n` macros as in usual rule actions, only here we DO NOT validate
    // their usefulness as the 'error reduce action' accepts a variable number of
    // production terms (available in `yyrulelength` in case you wish to address the
    // input terms directly in the `yyvstack` and `yylstack` arrays, for instance).
    //
    // This example recovery rule simply collects all parse info stored in the parse
    // stacks and which would otherwise be discarded immediately after this call, thus
    // keeping all parse info details up to the point of actual error RECOVERY available
    // to userland code in the handling 'error rule' in this grammar.
%}


%%

spec
    : declaration_list '%%' grammar optional_end_block EOF
        {
            $$ = $declaration_list;
            if ($optional_end_block && $optional_end_block.trim() !== '') {
                yy.addDeclaration($$, { include: $optional_end_block });
            }
            return extend($$, $grammar);
        }
    | declaration_list '%%' grammar error EOF
        {
            yyerror("Maybe you did not correctly separate trailing code from the grammar rule set with a '%%' marker on an otherwise empty line?\n\n  Erroneous area:\n" + prettyPrintRange(yylexer, @error, @grammar));
        }
    | declaration_list error EOF
        {
            yyerror("Maybe you did not correctly separate the parse 'header section' (token definitions, options, lexer spec, etc.) from the grammar rule set with a '%%' on an otherwise empty line?\n\n  Erroneous area:\n" + prettyPrintRange(yylexer, @error, @declaration_list));
        }
    ;

optional_end_block
    : %empty
        { $$ = undefined; }
    | '%%' extra_parser_module_code
        { $$ = $extra_parser_module_code; }
    ;

optional_action_header_block
    : %empty
        { $$ = {}; }
    | optional_action_header_block ACTION
        {
            $$ = $optional_action_header_block;
            yy.addDeclaration($$, { actionInclude: $ACTION });
        }
    | optional_action_header_block include_macro_code
        {
            $$ = $optional_action_header_block;
            yy.addDeclaration($$, { actionInclude: $include_macro_code });
        }
    ;

declaration_list
    : declaration_list declaration
        { $$ = $declaration_list; yy.addDeclaration($$, $declaration); }
    | %epsilon
        { $$ = {}; }
    | declaration_list error
        {
            // TODO ...
            yyerror("declaration list error?\n\n  Erroneous area:\n" + prettyPrintRange(yylexer, @error, @declaration_list));
        }
    ;

declaration
    : START id
        { $$ = {start: $id}; }
    | LEX_BLOCK
        { $$ = {lex: {text: $LEX_BLOCK, position: @LEX_BLOCK}}; }
    | operator
        { $$ = {operator: $operator}; }
    | TOKEN full_token_definitions
        { $$ = {token_list: $full_token_definitions}; }
    | ACTION
        { $$ = {include: $ACTION}; }
    | include_macro_code
        { $$ = {include: $include_macro_code}; }
    | parse_params
        { $$ = {parseParams: $parse_params}; }
    | parser_type
        { $$ = {parserType: $parser_type}; }
    | options
        { $$ = {options: $options}; }
    | DEBUG
        { $$ = {options: [['debug', true]]}; }
    | EBNF
        { $$ = {options: [['ebnf', true]]}; }
    | UNKNOWN_DECL
        { $$ = {unknownDecl: $UNKNOWN_DECL}; }
    | IMPORT import_name import_path
        { $$ = {imports: {name: $import_name, path: $import_path}}; }
    | IMPORT import_name error
        {
            yyerror("You did not specify a legal file path for the '%import' initialization code statement, which must have the format: '%import qualifier_name file_path'.\n\n  Erroneous area:\n" + prettyPrintRange(yylexer, @error, @IMPORT));
        }
    | IMPORT error import_path
        {
            yyerror("Each '%import'-ed initialization code section must be qualified by a name, e.g. 'required' before the import path itself: '%import qualifier_name file_path'.\n\n  Erroneous area:\n" + prettyPrintRange(yylexer, @error, @IMPORT));
        }
    | INIT_CODE init_code_name action_ne
        {
            $$ = {
                initCode: {
                    qualifier: $init_code_name,
                    include: $action_ne
                }
            };
        }
    | INIT_CODE error action_ne
        {
            yyerror("Each '%code' initialization code section must be qualified by a name, e.g. 'required' before the action code itself: '%code qualifier_name {action code}'.\n\n  Erroneous area:\n" + prettyPrintRange(yylexer, @error, @INIT_CODE, @action_ne));
        }
    | START error
        {
            // TODO ...
            yyerror("%start token error?\n\n  Erroneous area:\n" + prettyPrintRange(yylexer, @error, @START));
        }
    | TOKEN error
        {
            // TODO ...
            yyerror("%token definition list error?\n\n  Erroneous area:\n" + prettyPrintRange(yylexer, @error, @TOKEN));
        }
    | IMPORT error
        {
            // TODO ...
            yyerror("%import name or source filename missing maybe?\n\n  Erroneous area:\n" + prettyPrintRange(yylexer, @error, @IMPORT));
        }
//    | INIT_CODE error
    ;

init_code_name
    : ID
        { $$ = $ID; }
    | NAME
        { $$ = $NAME; }
    | STRING
        { $$ = $STRING; }
    ;

import_name
    : ID
        { $$ = $ID; }
    | STRING
        { $$ = $STRING; }
    ;

import_path
    : ID
        { $$ = $ID; }
    | STRING
        { $$ = $STRING; }
    ;

options
    : OPTIONS option_list OPTIONS_END
        { $$ = $option_list; }
    | OPTIONS error OPTIONS_END
        {
            // TODO ...
            yyerror("%options ill defined / error?\n\n  Erroneous area:\n" + prettyPrintRange(yylexer, @error, @OPTIONS, @OPTIONS_END));
        }
    | OPTIONS error
        {
            // TODO ...
            yyerror("%options don't seem terminated?\n\n  Erroneous area:\n" + prettyPrintRange(yylexer, @error, @OPTIONS));
        }
    ;

option_list
    : option_list option
        { $$ = $option_list; $$.push($option); }
    | option
        { $$ = [$option]; }
    ;

option
    : NAME[option]
        { $$ = [$option, true]; }
    | NAME[option] '=' OPTION_STRING_VALUE[value]
        { $$ = [$option, $value]; }
    | NAME[option] '=' OPTION_VALUE[value]
        { $$ = [$option, parseValue($value)]; }
    | NAME[option] '=' NAME[value]
        { $$ = [$option, parseValue($value)]; }
    | NAME[option] '=' error
        {
            // TODO ...
            yyerror(`named %option value error for ${$option}?` + "\n\n  Erroneous area:\n" + prettyPrintRange(yylexer, @error, @option));
        }
    | NAME[option] error
        {
            // TODO ...
            yyerror("named %option value assignment error?\n\n  Erroneous area:\n" + prettyPrintRange(yylexer, @error, @option));
        }
    ;

parse_params
    : PARSE_PARAM token_list
        { $$ = $token_list; }
    | PARSE_PARAM error
        {
            // TODO ...
            yyerror("%pase-params declaration error?\n\n  Erroneous area:\n" + prettyPrintRange(yylexer, @error, @PARSE_PARAM));
        }
    ;

parser_type
    : PARSER_TYPE symbol
        { $$ = $symbol; }
    | PARSER_TYPE error
        {
            // TODO ...
            yyerror("%parser-type declaration error?\n\n  Erroneous area:\n" + prettyPrintRange(yylexer, @error, @PARSER_TYPE));
        }
    ;

operator
    : associativity token_list
        { $$ = [$associativity]; $$.push.apply($$, $token_list); }
    | associativity error
        {
            // TODO ...
            yyerror("operator token list error in an associativity statement?\n\n  Erroneous area:\n" + prettyPrintRange(yylexer, @error, @associativity));
        }
    ;

associativity
    : LEFT
        { $$ = 'left'; }
    | RIGHT
        { $$ = 'right'; }
    | NONASSOC
        { $$ = 'nonassoc'; }
    ;

token_list
    : token_list symbol
        { $$ = $token_list; $$.push($symbol); }
    | symbol
        { $$ = [$symbol]; }
    ;

// As per http://www.gnu.org/software/bison/manual/html_node/Token-Decl.html
full_token_definitions
    : optional_token_type id_list
        {
            var rv = [];
            var lst = $id_list;
            for (var i = 0, len = lst.length; i < len; i++) {
                var id = lst[i];
                var m = {id: id};
                if ($optional_token_type) {
                    m.type = $optional_token_type;
                }
                rv.push(m);
            }
            $$ = rv;
        }
    | optional_token_type one_full_token
        {
            var m = $one_full_token;
            if ($optional_token_type) {
                m.type = $optional_token_type;
            }
            $$ = [m];
        }
    ;

one_full_token
    : id token_value token_description
        {
            $$ = {
                id: $id,
                value: $token_value,
                description: $token_description
            };
        }
    | id token_description
        {
            $$ = {
                id: $id,
                description: $token_description
            };
        }
    | id token_value
        {
            $$ = {
                id: $id,
                value: $token_value
            };
        }
    ;

optional_token_type
    : %epsilon
        { $$ = false; }
    | TOKEN_TYPE
        { $$ = $TOKEN_TYPE; }
    ;

token_value
    : INTEGER
        { $$ = $INTEGER; }
    ;

token_description
    : STRING
        { $$ = $STRING; }
    ;

id_list
    : id_list id
        { $$ = $id_list; $$.push($id); }
    | id
        { $$ = [$id]; }
    ;

// token_id
//     : TOKEN_TYPE id
//         { $$ = $id; }
//     | id
//         { $$ = $id; }
//     ;

grammar
    : optional_action_header_block production_list
        {
            $$ = $optional_action_header_block;
            $$.grammar = $production_list;
        }
    ;

production_list
    : production_list production
        {
            $$ = $production_list;
            if ($production[0] in $$) {
                $$[$production[0]] = $$[$production[0]].concat($production[1]);
            } else {
                $$[$production[0]] = $production[1];
            }
        }
    | production
        { $$ = {}; $$[$production[0]] = $production[1]; }
    ;

production
    : production_id handle_list ';'
        {$$ = [$production_id, $handle_list];}
    | production_id error ';'
        {
            // TODO ...
            yyerror("rule production declaration error?\n\n  Erroneous area:\n" + prettyPrintRange(yylexer, @error, @production_id));
        }
    | production_id error
        {
            // TODO ...
            yyerror("rule production declaration error: did you terminate the rule production set with a semicolon?\n\n  Erroneous area:\n" + prettyPrintRange(yylexer, @error, @production_id));
        }
    ;

production_id
    : id optional_production_description ':'
        {
            $$ = $id;

            // TODO: carry rule description support into the parser generator...
        }
    | id optional_production_description error
        {
            // TODO ...
            yyerror("rule id should be followed by a colon, but that one seems missing?\n\n  Erroneous area:\n" + prettyPrintRange(yylexer, @error, @id));
        }
    ;

optional_production_description
    : STRING
        { $$ = $STRING; }
    | %epsilon
    ;

handle_list
    : handle_list '|' handle_action
        {
            $$ = $handle_list;
            $$.push($handle_action);
        }
    | handle_action
        {
            $$ = [$handle_action];
        }
    | handle_list '|' error
        {
            // TODO ...
            yyerror("rule alternative production declaration error?\n\n  Erroneous area:\n" + prettyPrintRange(yylexer, @error, @handle_list));
        }
    | handle_list ':' error
        {
            // TODO ...
            yyerror("multiple alternative rule productions should be separated by a '|' pipe character, not a ':' colon!\n\n  Erroneous area:\n" + prettyPrintRange(yylexer, @error, @handle_list));
        }
    ;

handle_action
    : handle prec action
        {
            $$ = [($handle.length ? $handle.join(' ') : '')];
            if ($action) {
                $$.push($action);
            }
            if ($prec) {
                if ($handle.length === 0) {
                    yyerror("You cannot specify a precedence override for an epsilon (a.k.a. empty) rule!\n\n  Erroneous area:\n" + prettyPrintRange(yylexer, @handle));
                }
                $$.push($prec);
            }
            if ($$.length === 1) {
                $$ = $$[0];
            }
        }
    | EPSILON action
        // %epsilon may only be used to signal this is an empty rule alt;
        // hence it can only occur by itself
        // (with an optional action block, but no alias what-so-ever nor any precedence override).
        {
            $$ = [''];
            if ($action) {
                $$.push($action);
            }
            if ($$.length === 1) {
                $$ = $$[0];
            }
        }
    | EPSILON error
        {
            // TODO ...
            yyerror("%epsilon rule action declaration error?\n\n  Erroneous area:\n" + prettyPrintRange(yylexer, @error, @EPSILON));
        }
    ;

handle
    : handle suffixed_expression
        {
            $$ = $handle;
            $$.push($suffixed_expression);
        }
    | %epsilon
        {
            $$ = [];
        }
    ;

handle_sublist
    : handle_sublist '|' handle
        {
            $$ = $handle_sublist;
            $$.push($handle.join(' '));
        }
    | handle
        {
            $$ = [$handle.join(' ')];
        }
    ;

suffixed_expression
    : expression suffix ALIAS
        {
            $$ = $expression + $suffix + "[" + $ALIAS + "]";
        }
    | expression suffix
        {
            $$ = $expression + $suffix;
        }
    ;

expression
    : ID
        {
            $$ = $ID;
        }
    | EOF_ID
        {
            $$ = '$end';
        }
    | STRING
        {
            // Re-encode the string *anyway* as it will
            // be made part of the rule rhs a.k.a. production (type: *string*) again and we want
            // to be able to handle all tokens, including *significant space*
            // encoded as literal tokens in a grammar such as this: `rule: A ' ' B`.
            $$ = dquote($STRING);
        }
    | '(' handle_sublist ')'
        {
            $$ = '(' + $handle_sublist.join(' | ') + ')';
        }
    | '(' handle_sublist error
        {
            yyerror("Seems you did not correctly bracket a grammar rule sublist in '( ... )' brackets.\n\n  Erroneous area:\n" + prettyPrintRange(yylexer, @error, @1));
        }
    ;

suffix
    : %epsilon
        { $$ = ''; }
    | '*'
        { $$ = $1; }
    | '?'
        { $$ = $1; }
    | '+'
        { $$ = $1; }
    ;

prec
    : PREC symbol
        {
            $$ = { prec: $symbol };
        }
    | PREC error
        {
            // TODO ...
            yyerror("%prec precedence override declaration error?\n\n  Erroneous precedence declaration:\n" + prettyPrintRange(yylexer, @error, @PREC));
        }
    | %epsilon
        {
            $$ = null;
        }
    ;

symbol
    : id
        { $$ = $id; }
    | STRING
        { $$ = $STRING; }
    ;

id
    : ID
        { $$ = $ID; }
    ;

action_ne
    : '{' action_body '}'
        { $$ = $action_body; }
    | '{' action_body error
        {
            yyerror("Seems you did not correctly bracket a parser rule action block in curly braces: '{ ... }'.\n\n  Erroneous area:\n" + prettyPrintRange(yylexer, @error, @1));
        }
    | ACTION
        { $$ = $ACTION; }
    | include_macro_code
        { $$ = $include_macro_code; }
    | ARROW_ACTION
        { $$ = '$$ = ' + $ARROW_ACTION; }
    ;

action
    : action_ne
        { $$ = $action_ne; }
    | %epsilon
        { $$ = ''; }
    ;

action_body
    : %epsilon
        { $$ = ''; }
    | action_comments_body
        { $$ = $action_comments_body; }
    | action_body '{' action_body '}' action_comments_body
        { $$ = $1 + $2 + $3 + $4 + $5; }
    | action_body '{' action_body '}'
        { $$ = $1 + $2 + $3 + $4; }
    | action_body '{' action_body error
        {
            yyerror("Seems you did not correctly match curly braces '{ ... }' in a parser rule action block.\n\n  Erroneous area:\n" + prettyPrintRange(yylexer, @error, @2));
        }
    ;

action_comments_body
    : ACTION_BODY
        { $$ = $ACTION_BODY; }
    | action_comments_body ACTION_BODY
        { $$ = $action_comments_body + $ACTION_BODY; }
    ;

extra_parser_module_code
    : optional_module_code_chunk
        { $$ = $optional_module_code_chunk; }
    | optional_module_code_chunk include_macro_code extra_parser_module_code
        { $$ = $optional_module_code_chunk + $include_macro_code + $extra_parser_module_code; }
    ;

include_macro_code
    : INCLUDE PATH
        {
            var fs = require('fs');
            var fileContent = fs.readFileSync($PATH, { encoding: 'utf-8' });
            // And no, we don't support nested '%include':
            $$ = '\n// Included by Jison: ' + $PATH + ':\n\n' + fileContent + '\n\n// End Of Include by Jison: ' + $PATH + '\n\n';
        }
    | INCLUDE error
        {
            yyerror(rmCommonWS`
                %include MUST be followed by a valid file path.

                  Erroneous path:
                ` + prettyPrintRange(yylexer, @error, @INCLUDE));
        }
    ;

module_code_chunk
    : CODE
        { $$ = $CODE; }
    | module_code_chunk CODE
        { $$ = $module_code_chunk + $CODE; }
    | error
        {
            // TODO ...
            yyerror(rmCommonWS`
                module code declaration error?

                  Erroneous area:
                ` + prettyPrintRange(yylexer, @error));
        }
    ;

optional_module_code_chunk
    : module_code_chunk
        { $$ = $module_code_chunk; }
    | %epsilon
        { $$ = ''; }
    ;

%%

// properly quote and escape the given input string
function dquote(s) {
    var sq = (s.indexOf('\'') >= 0);
    var dq = (s.indexOf('"') >= 0);
    if (sq && dq) {
        s = s.replace(/"/g, '\\"');
        dq = false;
    }
    if (dq) {
        s = '\'' + s + '\'';
    }
    else {
        s = '"' + s + '"';
    }
    return s;
}

// transform ebnf to bnf if necessary
function extend(json, grammar) {
    json.bnf = ebnf ? transform(grammar.grammar) : grammar.grammar;
    if (grammar.actionInclude) {
        json.actionInclude = grammar.actionInclude;
    }
    return json;
}

// convert string value to number or boolean value, when possible
// (and when this is more or less obviously the intent)
// otherwise produce the string itself as value.
function parseValue(v) {
    if (v === 'false') {
        return false;
    }
    if (v === 'true') {
        return true;
    }
    // http://stackoverflow.com/questions/175739/is-there-a-built-in-way-in-javascript-to-check-if-a-string-is-a-valid-number
    // Note that the `v` check ensures that we do not convert `undefined`, `null` and `''` (empty string!)
    if (v && !isNaN(v)) {
        var rv = +v;
        if (isFinite(rv)) {
            return rv;
        }
    }
    return v;
}

// tagged template string helper which removes the indentation common to all
// non-empty lines: that indentation was added as part of the source code
// formatting of this lexer spec file and must be removed to produce what
// we were aiming for.
//
// Each template string starts with an optional empty line, which should be
// removed entirely, followed by a first line of error reporting content text,
// which should not be indented at all, i.e. the indentation of the first
// non-empty line should be treated as the 'common' indentation and thus
// should also be removed from all subsequent lines in the same template string.
//
// See also: https://developer.mozilla.org/en/docs/Web/JavaScript/Reference/Template_literals
function rmCommonWS(strings, ...values) {
    // as `strings[]` is an array of strings, each potentially consisting
    // of multiple lines, followed by one(1) value, we have to split each
    // individual string into lines to keep that bit of information intact.
    var src = strings.map(function splitIntoLines(s) {
        return s.split('\n');
    });
    // fetch the first line of content which is expected to exhibit the common indent:
    // that would be the SECOND line of input, always, as the FIRST line won't
    // have any indentation at all!
    var s0 = '';
    for (var i = 0, len = src.length; i < len; i++) {
        if (src[i].length > 1) {
            s0 = src[i][1];
            break;
        }
    }
    var indent = s0.replace(/^(\s+)[^\s]*.*$/, '$1');
    // we assume clean code style, hence no random mix of tabs and spaces, so every
    // line MUST have the same indent style as all others, so `length` of indent
    // should suffice, but the way we coded this is stricter checking when we apply
    // a find-and-replace regex instead:
    var indent_re = new RegExp('^' + indent);

    // process template string partials now:
    for (var i = 0, len = src.length; i < len; i++) {
        // start-of-lines always end up at index 1 and above (for each template string partial):
        for (var j = 1, linecnt = src[i].length; j < linecnt; j++) {
            src[i][j] = src[i][j].replace(indent_re, '');
        }
    }

    // now merge everything to construct the template result:
    var rv = [];
    for (var i = 0, len = src.length, klen = values.length; i < len; i++) {
        rv.push(src[i].join('\n'));
        // all but the last partial are followed by a template value:
        if (i < klen) {
            rv.push(values[i]);
        }
    }
    var sv = rv.join('');
    return sv;
}

// pretty-print the erroneous section of the input, with line numbers and everything...
function prettyPrintRange(lexer, loc, context_loc, context_loc2) {
    var error_size = loc.last_line - loc.first_line;
    const CONTEXT = 3;
    const CONTEXT_TAIL = 1;
    var input = lexer.matched + lexer._input;
    var lines = input.split('\n');
    var show_context = (error_size < 5 || context_loc);
    var l0 = Math.max(1, (!show_context ? loc.first_line : context_loc ? context_loc.first_line : loc.first_line - CONTEXT));
    var l1 = Math.max(1, (!show_context ? loc.last_line : context_loc2 ? context_loc2.last_line : loc.last_line + CONTEXT_TAIL));
    var lineno_display_width = (1 + Math.log10(l1 | 1) | 0);
    var ws_prefix = new Array(lineno_display_width).join(' ');
    var rv = lines.slice(l0 - 1, l1 + 1).map(function injectLineNumber(line, index) {
        var lno = index + l0;
        var lno_pfx = (ws_prefix + lno).substr(-lineno_display_width);
        var rv = lno_pfx + ': ' + line;
        if (show_context) {
            var errpfx = (new Array(lineno_display_width + 1)).join('^');
            if (lno === loc.first_line) {
                var offset = loc.first_column + 2;
                var len = Math.max(2, (lno === loc.last_line ? loc.last_column : line.length) - loc.first_column + 1);
                var lead = (new Array(offset)).join('.');
                var mark = (new Array(len)).join('^');
                rv += '\n' + errpfx + lead + mark + offset + '/D' + len + '/' + lno + '/' + loc.last_line + '/' + loc.last_column + '/' + line.length + '/' + loc.first_column;
            } else if (lno === loc.last_line) {
                var offset = 2 + 1;
                var len = Math.max(2, loc.last_column + 1);
                var lead = (new Array(offset)).join('.');
                var mark = (new Array(len)).join('^');
                rv += '\n' + errpfx + lead + mark + offset + '/E' + len;
            } else if (lno > loc.first_line && lno < loc.last_line) {
                var offset = 2 + 1;
                var len = Math.max(2, line.length + 1);
                var lead = (new Array(offset)).join('.');
                var mark = (new Array(len)).join('^');
                rv += '\n' + errpfx + lead + mark + offset + '/F' + len;
            }
        }
        rv = rv.replace(/\t/g, ' ');
        return rv;
    });
    return rv.join('\n');
}


parser.warn = function p_warn() {
    console.warn.apply(console, arguments);
};

parser.log = function p_log() {
    console.log.apply(console, arguments);
};

