%{
#include <iostream>
#include <fstream>
#include <sstream>
#include <cstdio>
#include <cstring>
#include "symbolTable.h"
#include "node.h"

using namespace std;

extern int yylex();
extern int yyparse();
void yyerror(const char* s);
extern FILE* yyin;

extern int line;
extern int column;
extern int tab;

bool outputProductions = false;
ifstream inputFile;
ofstream outputFile;
ofstream lexDebugOutput;
ofstream symbolTableOut;
stringstream outputStream;
stringstream errorStream;
void parserOutput(string s);

//Command line Parse
int parseCommandLine(int argc, char** argv);
bool command_l = false;
bool command_s = false;

symbolTable st;
string nodeIdentifier = "";
int nodeLineNumber = -1;
int nodeStorageClassSpecifier = -1;
int nodeTypeSpecifier = 3;
int nodeTypeQualifier = -1;
bool nodeIsFunction = false;
bool nodeIsSigned = true;
%}

%union
{
    char sval[255];
}

%define parse.error verbose

%token <sval> AUTO BREAK CASE CHAR CONST CONTINUE DEFAULT DO DOUBLE
%token <sval> ELLIPSIS ELSE ENUM EXTERN FLOAT FOR GOTO IF INT LONG
%token <sval> REGISTER RETURN SHORT SIGNED SIZEOF STATIC STRUCT SWITCH
%token <sval> TYPEDEF UNION UNSIGNED VOID VOLATILE WHILE

%token <sval> AMPERSAND ARROW ASSIGN COMMA PERIOD SEMICOLON STAR
%token <sval> OBRACE CBRACE OBRACKET CBRACKET OPAREN CPAREN QUESTION COLON
%token <sval> ADD SUB DIV MOD
%token <sval> INC_OP DEC_OP
%token <sval> ADD_ASSIGN SUB_ASSIGN MUL_ASSIGN DIV_ASSIGN MOD_ASSIGN
%token <sval> L_AND L_OR L_NOT
%token <sval> EQ_OP NE_OP GT_OP LT_OP GE_OP LE_OP
%token <sval> B_NOT B_OR B_XOR B_SL B_SR
%token <sval> B_AND_ASSIGN B_OR_ASSIGN B_XOR_ASSIGN B_SL_ASSIGN B_SR_ASSIGN

%token <sval> CHARACTER_CONSTANT ENUMERATION_CONSTANT FLOATING_CONSTANT INTEGER_CONSTANT
%token <sval> STRING_LITERAL TYPEDEF_NAME IDENTIFIER
%token <sval> ERROR

%%

translation_unit
	: external_declaration { parserOutput("translation_unit -> external_declaration"); }
	| translation_unit external_declaration { parserOutput("translation_unit -> translation_unit external_declaration"); }
	;

external_declaration
	: function_definition { parserOutput("external_declaration -> function_definition"); }
	| declaration { parserOutput("external_declaration -> declaration"); }
	;

function_definition
	: declarator compound_statement { parserOutput("function_definition -> declarator compound_statement"); st.popLevel(); }
	| declarator declaration_list compound_statement { parserOutput("function_definition -> declarator declaration_list compound_statement"); st.popLevel(); }
	| declaration_specifiers declarator compound_statement { parserOutput("function_definition -> declaration_specifiers declarator compound_statement"); st.popLevel(); }
	| declaration_specifiers declarator declaration_list compound_statement { parserOutput("function_definition -> declaration_specifiers declarator declaration_list compound_statement"); st.popLevel(); }
	;

declaration
	: declaration_specifiers SEMICOLON { parserOutput("declaration -> declaration_specifiers SEMICOLON"); }
	| declaration_specifiers init_declarator_list SEMICOLON { parserOutput("declaration -> declaration_specifiers init_declarator_list SEMICOLON"); }
	;

declaration_list
	: declaration { parserOutput("declaration_list -> declaration"); st.setInsertMode(false); }
	| declaration_list declaration { parserOutput("declaration_list -> declaration_list declaration"); st.setInsertMode(false); }
	;

declaration_specifiers
	: storage_class_specifier { parserOutput("declaration_specifiers -> storage_class_specifier"); }
	| storage_class_specifier declaration_specifiers { parserOutput("declaration_specifiers -> storage_class_specifier declaration_specifiers"); }
	| type_specifier { parserOutput("declaration_specifiers -> type_specifier"); }
	| type_specifier declaration_specifiers { parserOutput("declaration_specifiers -> type_specifier declaration_specifiers"); }
	| type_qualifier { parserOutput("declaration_specifiers -> type_qualifier"); }
	| type_qualifier declaration_specifiers { parserOutput("declaration_specifiers -> type_qualifier declaration_specifiers"); }
	;

storage_class_specifier
	: AUTO { parserOutput("storage_class_specifier -> AUTO"); st.setInsertMode(true); nodeStorageClassSpecifier = 0; }
	| REGISTER { parserOutput("storage_class_specifier -> REGISTER"); st.setInsertMode(true); nodeStorageClassSpecifier = 1; }
	| STATIC { parserOutput("storage_class_specifier -> STATIC"); st.setInsertMode(true); nodeStorageClassSpecifier = 2; }
	| EXTERN { parserOutput("storage_class_specifier -> EXTERN"); st.setInsertMode(true); nodeStorageClassSpecifier = 3; }
	| TYPEDEF { parserOutput("storage_class_specifier -> TYPEDEF"); st.setInsertMode(true); nodeStorageClassSpecifier = 4; }
	;

type_specifier
	: VOID { parserOutput("type_specifier -> VOID"); st.setInsertMode(true); nodeTypeSpecifier = 0; }
	| CHAR { parserOutput("type_specifier -> CHAR"); st.setInsertMode(true); nodeTypeSpecifier = 1; }
	| SHORT { parserOutput("type_specifier -> SHORT"); st.setInsertMode(true); nodeTypeSpecifier = 2; }
	| INT { parserOutput("type_specifier -> INT"); st.setInsertMode(true); nodeTypeSpecifier = 3; }
	| LONG { parserOutput("type_specifier -> LONG"); st.setInsertMode(true); nodeTypeSpecifier = 4; }
	| FLOAT { parserOutput("type_specifier -> FLOAT"); st.setInsertMode(true); nodeTypeSpecifier = 5; }
	| DOUBLE { parserOutput("type_specifier -> DOUBLE"); st.setInsertMode(true); nodeTypeSpecifier = 6; }
	| SIGNED { parserOutput("type_specifier -> SIGNED"); st.setInsertMode(true); nodeIsSigned = true; }
	| UNSIGNED { parserOutput("type_specifier -> UNSIGNED"); st.setInsertMode(true); nodeIsSigned = false; }
	| struct_or_union_specifier { parserOutput("type_specifier -> struct_or_union_specifier"); }
	| enum_specifier { parserOutput("type_specifier -> enum_specifier"); /* TODO: Enums... one day... */ }
	| TYPEDEF_NAME { parserOutput("type_specifier -> TYPEDEF_NAME"); /* TODO: typedefs in symbol table */ }
	;

type_qualifier
	: CONST { parserOutput("type_qualifier -> CONST"); st.setInsertMode(true); nodeTypeQualifier = 0; }
	| VOLATILE { parserOutput("type_qualifier -> VOLATILE"); st.setInsertMode(true); nodeTypeQualifier = 1; }
	;

struct_or_union_specifier
	: struct_or_union identifier OBRACE struct_declaration_list CBRACE { parserOutput("struct_or_union_specifier -> struct_or_union identifier OBRACE struct_declaration_list CBRACE"); }
	| struct_or_union OBRACE struct_declaration_list CBRACE { parserOutput("struct_or_union_specifier -> struct_or_union OBRACE struct_declaration_list CBRACE"); }
	| struct_or_union identifier { parserOutput("struct_or_union_specifier -> struct_or_union identifier"); }
	;

struct_or_union
	: STRUCT { parserOutput("struct_or_union -> STRUCT"); nodeTypeSpecifier = 7; }
	| UNION { parserOutput("struct_or_union -> UNION"); }
	;

struct_declaration_list
	: struct_declaration { parserOutput("struct_declaration_list -> struct_declaration"); }
	| struct_declaration_list struct_declaration { parserOutput("struct_declaration_list -> struct_declaration_list struct_declaration"); }
	;

init_declarator_list
	: init_declarator { parserOutput("init_declarator_list -> init_declarator"); }
	| init_declarator_list COMMA init_declarator { parserOutput("init_declarator_list -> init_declarator_list COMMA init_declarator"); }
	;

init_declarator
	: declarator { parserOutput("init_declarator -> declarator"); }
	| declarator ASSIGN initializer { parserOutput("init_declarator -> declarator ASSIGN initializer"); }
	;

struct_declaration
	: specifier_qualifier_list struct_declarator_list SEMICOLON { parserOutput("struct_declaration -> specifier_qualifier_list struct_declarator_list SEMICOLON"); }
	;

specifier_qualifier_list
	: type_specifier { parserOutput("specifier_qualifier_list -> type_specifier"); }
	| type_specifier specifier_qualifier_list { parserOutput("specifier_qualifier_list -> type_specifier specifier_qualifier_list"); }
	| type_qualifier { parserOutput("specifier_qualifier_list -> type_qualifier"); }
	| type_qualifier specifier_qualifier_list { parserOutput("specifier_qualifier_list -> type_qualifier specifier_qualifier_list"); }
	;

struct_declarator_list
	: struct_declarator { parserOutput("struct_declarator_list -> struct_declarator"); }
	| struct_declarator_list COMMA struct_declarator { parserOutput("struct_declarator_list -> struct_declarator_list COMMA struct_declarator"); }
	;

struct_declarator
	: declarator { parserOutput("struct_declarator -> declarator"); }
	| COLON constant_expression { parserOutput("struct_declarator -> COLON constant_expression"); }
	| declarator COLON constant_expression { parserOutput("struct_declarator -> declarator COLON constant_expression"); }
	;

enum_specifier
	: ENUM OBRACE enumerator_list CBRACE { parserOutput("enum_specifier -> ENUM OBRACE enumerator_list CBRACE"); }
	| ENUM identifier OBRACE enumerator_list CBRACE { parserOutput("enum_specifier -> ENUM identifier OBRACE enumerator_list CBRACE"); }
	| ENUM identifier { parserOutput("enum_specifier -> ENUM identifier"); }
	;

enumerator_list
	: enumerator { parserOutput("enumerator_list -> enumerator"); }
	| enumerator_list COMMA enumerator { parserOutput("enumerator_list -> enumerator_list COMMA enumerator"); }
	;

enumerator
	: identifier { parserOutput("enumerator -> identifier"); }
	| identifier ASSIGN constant_expression { parserOutput("enumerator -> identifier ASSIGN constant_expression"); }
	;

declarator
	: direct_declarator { parserOutput("declarator -> direct_declarator"); }
	| pointer direct_declarator { parserOutput("declarator -> pointer direct_declarator"); }
	;

direct_declarator
	: identifier    { 
                        parserOutput("direct_declarator -> identifier");
                        node node(nodeIdentifier, line, column, nodeTypeSpecifier);
                        node.setTypeStorageClassIndex(nodeStorageClassSpecifier);
                        node.setTypeQualifierIndex(nodeTypeQualifier);
                        node.setIsFunction(nodeIsFunction);
                        node.setIsSigned(nodeIsSigned);
                        
                        if (!st.insert(node))
                        {
                            return 1;
                        }

                        nodeIdentifier = "";
                        nodeLineNumber = -1;
                        nodeStorageClassSpecifier = -1;
                        nodeTypeSpecifier = 3;
                        nodeTypeQualifier = -1;
                        nodeIsFunction = false;
                        nodeIsSigned = true;
                    }
	| OPAREN declarator CPAREN { parserOutput("direct_declarator -> OPAREN declarator CPAREN"); }
	| direct_declarator OBRACKET CBRACKET { parserOutput("direct_declarator -> direct_declarator OBRACKET CBRACKET"); }
	| direct_declarator OBRACKET constant_expression CBRACKET { parserOutput("direct_declarator -> direct_declarator OBRACKET constant_expression CBRACKET"); }
	| direct_declarator OPAREN CPAREN { parserOutput("direct_declarator -> direct_declarator OPAREN CPAREN"); }
	| direct_declarator OPAREN parameter_type_list CPAREN { parserOutput("direct_declarator -> direct_declarator OPAREN parameter_type_list CPAREN"); }
	| direct_declarator OPAREN identifier_list CPAREN { parserOutput("direct_declarator -> direct_declarator OPAREN identifier_list CPAREN"); }
	;

pointer
	: STAR { parserOutput("pointer -> STAR"); }
	| STAR type_qualifier_list { parserOutput("pointer -> STAR type_qualifier_list"); }
	| STAR pointer { parserOutput("pointer -> STAR pointer"); }
	| STAR type_qualifier_list pointer { parserOutput("pointer -> STAR type_qualifier_list pointer"); }
	;

type_qualifier_list
	: type_qualifier { parserOutput("type_qualifier_list -> type_qualifier"); }
	| type_qualifier_list type_qualifier { parserOutput("type_qualifier_list -> type_qualifier_list type_qualifier"); }
	;

parameter_type_list
	: parameter_list { parserOutput("parameter_type_list -> parameter_list"); }
	| parameter_list COMMA ELLIPSIS { parserOutput("parameter_type_list -> parameter_list COMMA ELLIPSIS"); }
	;

parameter_list
	: parameter_declaration { parserOutput("parameter_list -> parameter_declaration"); }
	| parameter_list COMMA parameter_declaration { parserOutput("parameter_list -> parameter_list COMMA parameter_declaration"); }
	;

parameter_declaration
	: declaration_specifiers declarator { parserOutput("parameter_declaration -> declaration_specifiers declarator"); }
	| declaration_specifiers { parserOutput("parameter_declaration -> declaration_specifiers"); }
	| declaration_specifiers abstract_declarator { parserOutput("parameter_declaration -> declaration_specifiers abstract_declarator"); }
	;

identifier_list
	: identifier { parserOutput("identifier_list -> identifier"); }
	| identifier_list COMMA identifier { parserOutput("identifier_list -> identifier_list COMMA identifier"); }
	;

initializer
	: assignment_expression { parserOutput("initializer -> assignment_expression"); }
	| OBRACE initializer_list CBRACE { parserOutput("initializer -> OBRACE initializer_list CBRACE"); }
	| OBRACE initializer_list COMMA CBRACE { parserOutput("initializer -> OBRACE initializer_list COMMA CBRACE"); }
	;

initializer_list
	: initializer { parserOutput("initializer_list -> initializer"); }
	| initializer_list COMMA initializer { parserOutput("initializer_list -> initializer_list COMMA initializer"); }
	;

type_name
	: specifier_qualifier_list { parserOutput("type_name -> specifier_qualifier_list"); }
	| specifier_qualifier_list abstract_declarator { parserOutput("type_name -> specifier_qualifier_list abstract_declarator"); }
	;

abstract_declarator
	: pointer { parserOutput("abstract_declarator -> pointer"); }
	| direct_abstract_declarator { parserOutput("abstract_declarator -> direct_abstract_declarator"); }
	| pointer direct_abstract_declarator { parserOutput("abstract_declarator -> pointer direct_abstract_declarator"); }
	;

direct_abstract_declarator
	: OPAREN abstract_declarator CPAREN { parserOutput("direct_abstract_declarator -> OPAREN abstract_declarator CPAREN"); }
	| OBRACKET CBRACKET { parserOutput("direct_abstract_declarator -> OBRACKET CBRACKET"); }
	| OBRACKET constant_expression CBRACKET { parserOutput("direct_abstract_declarator -> OBRACKET constant_expression CBRACKET"); }
	| direct_abstract_declarator OBRACKET CBRACKET { parserOutput("direct_abstract_declarator -> direct_abstract_declarator OBRACKET CBRACKET"); }
	| direct_abstract_declarator OBRACKET constant_expression CBRACKET { parserOutput("direct_abstract_declarator -> direct_abstract_declarator OBRACKET constant_expression CBRACKET"); }
	| OPAREN CPAREN { parserOutput("direct_abstract_declarator -> OPAREN CPAREN"); }
	| OPAREN parameter_type_list CPAREN { parserOutput("direct_abstract_declarator -> OPAREN parameter_type_list CPAREN"); }
	| direct_abstract_declarator OPAREN CPAREN { parserOutput("direct_abstract_declarator -> direct_abstract_declarator OPAREN CPAREN"); }
	| direct_abstract_declarator OPAREN parameter_type_list CPAREN { parserOutput("direct_abstract_declarator -> direct_abstract_declarator OPAREN parameter_type_list CPAREN"); }
	;

statement
	: labeled_statement { parserOutput("statement -> labeled_statement"); }
	| compound_statement { parserOutput("statement -> compound_statement"); }
	| expression_statement { parserOutput("statement -> expression_statement"); }
	| selection_statement { parserOutput("statement -> selection_statement"); }
	| iteration_statement { parserOutput("statement -> iteration_statement"); }
	| jump_statement { parserOutput("statement -> jump_statement"); }
	;

labeled_statement
	: identifier COLON statement { parserOutput("labeled_statement -> identifier COLON statement"); }
	| CASE constant_expression COLON statement { parserOutput("labeled_statement -> CASE constant_expression COLON statement"); }
	| DEFAULT COLON statement { parserOutput("labeled_statement -> DEFAULT COLON statement"); }
	;

expression_statement
	: SEMICOLON { parserOutput("expression_statement -> SEMICOLON"); }
	| expression SEMICOLON { parserOutput("expression_statement -> expression SEMICOLON"); }
	;

compound_statement
	: OBRACE CBRACE { parserOutput("compound_statement -> OBRACE CBRACE"); }
	| OBRACE statement_list CBRACE { parserOutput("compound_statement -> OBRACE statement_list CBRACE"); }
	| OBRACE declaration_list CBRACE { parserOutput("compound_statement -> OBRACE declaration_list CBRACE"); }
	| OBRACE declaration_list statement_list CBRACE { parserOutput("compound_statement -> OBRACE declaration_list statement_list CBRACE"); }
	;

statement_list
	: statement { parserOutput("statement_list -> statement"); }
	| statement_list statement { parserOutput("statement_list -> statement_list statement"); }
	;

selection_statement
	: IF OPAREN expression CPAREN statement { parserOutput("selection_statement -> IF OPAREN expression CPAREN statement"); }
	| IF OPAREN expression CPAREN statement ELSE statement { parserOutput("selection_statement -> IF OPAREN expression CPAREN statement ELSE statement"); }
	| SWITCH OPAREN expression CPAREN statement { parserOutput("selection_statement -> SWITCH OPAREN expression CPAREN statement"); }
	;

iteration_statement
	: WHILE OPAREN expression CPAREN statement { parserOutput("iteration_statement -> WHILE OPAREN expression CPAREN statement"); }
	| DO statement WHILE OPAREN expression CPAREN SEMICOLON { parserOutput("iteration_statement -> DO statement WHILE OPAREN expression CPAREN SEMICOLON"); }
	| FOR OPAREN SEMICOLON SEMICOLON CPAREN statement { parserOutput("iteration_statement -> FOR OPAREN SEMICOLON SEMICOLON CPAREN statement"); }
	| FOR OPAREN SEMICOLON SEMICOLON expression CPAREN statement { parserOutput("iteration_statement -> FOR OPAREN SEMICOLON SEMICOLON expression CPAREN statement"); }
	| FOR OPAREN SEMICOLON expression SEMICOLON CPAREN statement { parserOutput("iteration_statement -> FOR OPAREN SEMICOLON expression SEMICOLON CPAREN statement"); }
	| FOR OPAREN SEMICOLON expression SEMICOLON expression CPAREN statement { parserOutput("iteration_statement -> FOR OPAREN SEMICOLON expression SEMICOLON expression CPAREN statement"); }
	| FOR OPAREN expression SEMICOLON SEMICOLON CPAREN statement { parserOutput("iteration_statement -> FOR OPAREN expression SEMICOLON SEMICOLON CPAREN statement"); }
	| FOR OPAREN expression SEMICOLON SEMICOLON expression CPAREN statement { parserOutput("iteration_statement -> FOR OPAREN expression SEMICOLON SEMICOLON expression CPAREN statement"); }
	| FOR OPAREN expression SEMICOLON expression SEMICOLON CPAREN statement { parserOutput("iteration_statement -> FOR OPAREN expression SEMICOLON expression SEMICOLON CPAREN statement"); }
	| FOR OPAREN expression SEMICOLON expression SEMICOLON expression CPAREN statement { parserOutput("iteration_statement -> FOR OPAREN expression SEMICOLON expression SEMICOLON expression CPAREN statement"); }
	;

jump_statement
	: GOTO identifier SEMICOLON { parserOutput("jump_statement -> GOTO identifier SEMICOLON"); }
	| CONTINUE SEMICOLON { parserOutput("jump_statement -> CONTINUE SEMICOLON"); }
	| BREAK SEMICOLON { parserOutput("jump_statement -> BREAK SEMICOLON"); }
	| RETURN SEMICOLON { parserOutput("jump_statement -> RETURN SEMICOLON"); }
	| RETURN expression SEMICOLON { parserOutput("jump_statement -> RETURN expression SEMICOLON"); }
	;

expression
	: assignment_expression { parserOutput("expression -> assignment_expression"); }
	| expression COMMA assignment_expression { parserOutput("expression -> expression COMMA assignment_expression"); }
	;

assignment_expression
	: conditional_expression { parserOutput("assignment_expression -> conditional_expression"); }
	| unary_expression assignment_operator assignment_expression { parserOutput("assignment_expression -> unary_expression assignment_operator assignment_expression"); }
	;

assignment_operator
	: ASSIGN { parserOutput("assignment_operator -> ASSIGN"); }
	| MUL_ASSIGN { parserOutput("assignment_operator -> MUL_ASSIGN"); }
	| DIV_ASSIGN { parserOutput("assignment_operator -> DIV_ASSIGN"); }
	| MOD_ASSIGN { parserOutput("assignment_operator -> MOD_ASSIGN"); }
	| ADD_ASSIGN { parserOutput("assignment_operator -> ADD_ASSIGN"); }
	| SUB_ASSIGN { parserOutput("assignment_operator -> SUB_ASSIGN"); }
	| B_SL_ASSIGN { parserOutput("assignment_operator -> B_SL_ASSIGN"); }
	| B_SR_ASSIGN { parserOutput("assignment_operator -> B_SR_ASSIGN"); }
	| B_AND_ASSIGN { parserOutput("assignment_operator -> B_AND_ASSIGN"); }
	| B_XOR_ASSIGN { parserOutput("assignment_operator -> B_XOR_ASSIGN"); }
	| B_OR_ASSIGN { parserOutput("assignment_operator -> B_OR_ASSIGN"); }
	;

conditional_expression
	: logical_or_expression { parserOutput("conditional_expression -> logical_or_expression"); }
	| logical_or_expression QUESTION expression COLON conditional_expression { parserOutput("conditional_expression -> logical_or_expression QUESTION expression COLON conditional_expression"); }
	;

constant_expression
	: conditional_expression { parserOutput("constant_expression -> conditional_expression"); }
	;

logical_or_expression
	: logical_and_expression { parserOutput("logical_or_expression -> logical_and_expression"); }
	| logical_or_expression L_OR logical_and_expression { parserOutput("logical_or_expression -> logical_or_expression L_OR logical_and_expression"); }
	;

logical_and_expression
	: inclusive_or_expression { parserOutput("logical_and_expression -> inclusive_or_expression"); }
	| logical_and_expression L_AND inclusive_or_expression { parserOutput("logical_and_expression -> logical_and_expression L_AND inclusive_or_expression"); }
	;

inclusive_or_expression
	: exclusive_or_expression { parserOutput("inclusive_or_expression -> exclusive_or_expression"); }
	| inclusive_or_expression B_OR exclusive_or_expression { parserOutput("inclusive_or_expression -> inclusive_or_expression B_OR exclusive_or_expression"); }
	;

exclusive_or_expression
	: and_expression { parserOutput("exclusive_or_expression -> and_expression"); }
	| exclusive_or_expression B_XOR and_expression { parserOutput("exclusive_or_expression -> exclusive_or_expression B_XOR and_expression"); }
	;

and_expression
	: equality_expression { parserOutput("and_expression -> equality_expression"); }
	| and_expression AMPERSAND equality_expression { parserOutput("and_expression -> and_expression AMPERSAND equality_expression"); }
	;

equality_expression
	: relational_expression { parserOutput("equality_expression -> relational_expression"); }
	| equality_expression EQ_OP relational_expression { parserOutput("equality_expression -> equality_expression EQ_OP relational_expression"); }
	| equality_expression NE_OP relational_expression { parserOutput("equality_expression -> equality_expression NE_OP relational_expression"); }
	;

relational_expression
	: shift_expression { parserOutput("relational_expression -> shift_expression"); }
	| relational_expression LT_OP shift_expression { parserOutput("relational_expression -> relational_expression LT_OP shift_expression"); }
	| relational_expression GT_OP shift_expression { parserOutput("relational_expression -> relational_expression GT_OP shift_expression"); }
	| relational_expression LE_OP shift_expression { parserOutput("relational_expression -> relational_expression LE_OP shift_expression"); }
	| relational_expression GE_OP shift_expression { parserOutput("relational_expression -> relational_expression GE_OP shift_expression"); }
	;

shift_expression
	: additive_expression { parserOutput("shift_expression -> additive_expression"); }
	| shift_expression B_SL additive_expression { parserOutput("shift_expression -> shift_expression B_SL additive_expression"); }
	| shift_expression B_SR additive_expression { parserOutput("shift_expression -> shift_expression B_SR additive_expression"); }
	;

additive_expression
	: multiplicative_expression { parserOutput("additive_expression -> multiplicative_expression"); }
	| additive_expression ADD multiplicative_expression { parserOutput("additive_expression -> additive_expression ADD multiplicative_expression"); }
	| additive_expression SUB multiplicative_expression { parserOutput("additive_expression -> additive_expression SUB multiplicative_expression"); }
	;

multiplicative_expression
	: cast_expression { parserOutput("multiplicative_expression -> cast_expression"); }
	| multiplicative_expression STAR cast_expression { parserOutput("multiplicative_expression -> multiplicative_expression STAR cast_expression"); }
	| multiplicative_expression DIV cast_expression { parserOutput("multiplicative_expression -> multiplicative_expression DIV cast_expression"); }
	| multiplicative_expression MOD cast_expression { parserOutput("multiplicative_expression -> multiplicative_expression MOD cast_expression"); }
	;

cast_expression
	: unary_expression { parserOutput("cast_expression -> unary_expression"); }
	| OPAREN type_name CPAREN cast_expression { parserOutput("cast_expression -> OPAREN type_name CPAREN cast_expression"); }
	;

unary_expression
	: postfix_expression { parserOutput("unary_expression -> postfix_expression"); }
	| INC_OP unary_expression { parserOutput("unary_expression -> INC_OP unary_expression"); }
	| DEC_OP unary_expression { parserOutput("unary_expression -> DEC_OP unary_expression"); }
	| unary_operator cast_expression { parserOutput("unary_expression -> unary_operator cast_expression"); }
	| SIZEOF unary_expression { parserOutput("unary_expression -> SIZEOF unary_expression"); }
	| SIZEOF OPAREN type_name CPAREN { parserOutput("unary_expression -> SIZEOF OPAREN type_name CPAREN"); }
	;

unary_operator
	: AMPERSAND { parserOutput("unary_operator -> AMPERSAND"); }
	| STAR { parserOutput("unary_operator -> STAR"); }
	| ADD { parserOutput("unary_operator -> ADD"); }
	| SUB { parserOutput("unary_operator -> SUB"); }
	| B_NOT { parserOutput("unary_operator -> B_NOT"); }
	| L_NOT { parserOutput("unary_operator -> L_NOT"); }
	;

postfix_expression
	: primary_expression { parserOutput("postfix_expression -> primary_expression"); }
	| postfix_expression OBRACKET expression CBRACKET { parserOutput("postfix_expression -> postfix_expression OBRACKET expression CBRACKET"); }
	| postfix_expression OPAREN CPAREN { parserOutput("postfix_expression -> postfix_expression OPAREN CPAREN"); }
	| postfix_expression OPAREN argument_expression_list CPAREN { parserOutput("postfix_expression -> postfix_expression OPAREN argument_expression_list CPAREN"); }
	| postfix_expression PERIOD identifier { parserOutput("postfix_expression -> postfix_expression PERIOD identifier"); }
	| postfix_expression ARROW identifier { parserOutput("postfix_expression -> postfix_expression ARROW identifier"); }
	| postfix_expression INC_OP { parserOutput("postfix_expression -> postfix_expression INC_OP"); }
	| postfix_expression DEC_OP { parserOutput("postfix_expression -> postfix_expression DEC_OP"); }
	;

primary_expression
	: identifier { parserOutput("primary_expression -> identifier"); }
	| constant { parserOutput("primary_expression -> constant"); }
	| string { parserOutput("primary_expression -> string"); }
	| OPAREN expression CPAREN { parserOutput("primary_expression -> OPAREN expression CPAREN"); }
	;

argument_expression_list
	: assignment_expression { parserOutput("argument_expression_list -> assignment_expression"); }
	| argument_expression_list COMMA assignment_expression { parserOutput("argument_expression_list -> argument_expression_list COMMA assignment_expression"); }
	;

constant
	: INTEGER_CONSTANT { parserOutput("constant -> INTEGER_CONSTANT"); }
	| CHARACTER_CONSTANT { parserOutput("constant -> CHARACTER_CONSTANT"); }
	| FLOATING_CONSTANT { parserOutput("constant -> FLOATING_CONSTANT"); }
	| ENUMERATION_CONSTANT { parserOutput("constant -> ENUMERATION_CONSTANT"); }
	;

string
	: STRING_LITERAL { parserOutput("string -> STRING_LITERAL"); }
	;

identifier
	: IDENTIFIER {
                    parserOutput("identifier -> IDENTIFIER"); 
                    nodeIdentifier = yylval.sval; 
                    nodeLineNumber = line;
                    if (!st.getInsertMode() && st.searchAll(nodeIdentifier).first == -1)
                    {
                        yyerror(NULL);
                        return 1;
                    }
                 }
	;

%%

int main(int argc, char** argv)
{
	int outputIndex = parseCommandLine(argc, argv); //Returns the index of the output file in argv or 0 if there is no -o

	yyparse();

    outputFile.open( outputIndex ? argv[outputIndex] : "defaultOutput.txt");
    if (outputFile.good())
    {
        outputFile << outputStream.str();
        outputFile << errorStream.str();
        cerr << errorStream.str();
    }
    else
    {
		cerr << "Output file fail." << endl;
        exit(-1);
    }

	  return 0;
}

/// @name yyerror
/// @brief This is the general syntax error function for the parser.
///        It will output the line and column number the error occurred on.
///        The output will first go to an error stream (a stringstream).
///        The error stream is then flushed to the output file and cerr.

void yyerror(const char* s)
{
    if (inputFile.good())
    {
        string currentLine;
        for (int i = 0; i < line; i++)
        {
            getline(inputFile, currentLine);
        }
        errorStream << currentLine << endl;
    }

    for (int i = 0; i < tab; i++)
    {
        errorStream << "\t";
    }

    for (int i = 0; i < column; i++)
    {
        errorStream << " ";
    }

    errorStream << "^ Error on line " << line << ", column " << column << "." << endl;
    outputStream << errorStream.str();
}

/// @name parserOutput
/// @brief This function simply adds the rule used to the output file, if the option
///        to have debugging productions is on.

void parserOutput(string s)
{
    if (outputProductions)
    {
        outputStream << "Rule: " << s << endl;
    }
}

/// @name parseCommandLine
/// @brief Handles and command line arguments.
///        Returns the argv index of the output file, if it exists, else returns 0.
int parseCommandLine(int argc, char** argv)
{
	int outputIndex = 0;
	const int num_options = 4;
	const char* valid_options[] {
		"-d",
		"-l",
		"-s",
		"-o"
	};

    inputFile.open(argv[1]); //Assumes the first command line arguement is the input file.
    FILE* inputStream = fopen(argv[1], "r");
    if (!inputStream)
    {
        cerr << "Cannot open input file." << endl;
		exit(-1);
    }
    else
    {
        yyin = inputStream;
    }


	for(int i = 2 ; i < argc ; ++i) //Skips the input file name
	{
		for(int j = 0 ; j < num_options ; ++j)
		{
			if( strcmp(valid_options[j], argv[i]) == 0 )
			{
				switch( argv[i][1] ) //Get the single character of the command line arguement
				{
					case 'd': command_s = command_l = true; //Both debug to true.
						break;
					case 'l': command_l = true;
						break;
					case 's': command_s = true;
						break;
					case 'o': outputIndex = ++i;
						if(i >= argc)
						{
							cerr << "ERROR: Please provide an output file with -o" << endl;
							exit(-1);
						}
						break;
					default:
						cerr << "Invalid command line argument" << endl;
						exit(-1);
						break;
				}
			}
		}
	}
	if(command_l)//Open the lex debug if the command line argument l was set.
	{
		lexDebugOutput.open( "LexDebugOutput.txt" );
		if( !lexDebugOutput.good() )
		{
			cerr << "Failed to open LexDebugOutput.txt" << endl;
			exit(-1);
		}
	}
	if(command_s)
	{
		symbolTableOut.open( "SymbolTableDump.txt" );
		if( !symbolTableOut.good() )
		{
			cerr << "Failed to open SymbolTableDump.txt" << endl;
			exit(-1);
		}
	}
	return outputIndex;
    
}