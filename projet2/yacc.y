%{
/* -------------------- Prologue 区域 -------------------- */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* ========== 全局声明区域，可放变量表、AST 定义、函数实现等 ========== */
#define VAR_COUNT 100

int yylex();
int yyerror(const char *s);

typedef struct {
    char name[50];
    int value;
} Variable;

Variable vars[VAR_COUNT];
int var_count = 0;

int getVarIndex(const char *name) {
    for (int i = 0; i < var_count; i++) {
        if (strcmp(vars[i].name, name) == 0)
            return i;
    }
    return -1;
}

/* AST 节点类型 */
typedef enum {
    AST_PROGRAM,
    AST_STMTLIST,
    AST_DECL,     /* int x=expr; */
    AST_ASSIGN,   /* x=expr; */
    AST_EXPRSTMT, /* expr; */
    AST_IF,
    AST_WHILE,
    AST_PRINT,
    AST_BLOCK,    /* { stmtlist } */
    AST_BINOP,
    AST_UNOP,
    AST_INTLIT,
    AST_IDENT,
    AST_CONDEXPR
} NodeKind;

/* 运算符类型 */
typedef enum {
    OP_PLUS, OP_MINUS, OP_MULT, OP_DIV,
    OP_COMP_EQ, OP_COMP_NE, OP_COMP_LT, OP_COMP_GT, OP_COMP_LE, OP_COMP_GE,
    OP_UNARY_MINUS
} OpKind;

/* AST 结构定义 */
typedef struct ASTNode {
    NodeKind kind;
    struct ASTNode *next; /* 用于将语句串成链表 */

    union {
        int ival;        /* 整数常量 */
        char *sval;      /* 标识符 */
        /* 二元/一元运算 */
        struct {
            OpKind op;
            struct ASTNode *left;
            struct ASTNode *right;
        } opr;
        /* if 语句 */
        struct {
            struct ASTNode *cond;
            struct ASTNode *ifBlock;
            struct ASTNode *elseBlock;
        } ifStmt;
        /* while 语句 */
        struct {
            struct ASTNode *cond;
            struct ASTNode *body;
        } whileStmt;
        /* 声明/赋值 */
        struct {
            char *varName;
            struct ASTNode *expr;
        } varStmt;
        /* printf(ident) */
        char *printVar;
        /* block 或 stmtlist 的 child */
        struct ASTNode *child;
    } u;
} ASTNode;

/* ===== 工厂函数声明 & 实现 ===== */
ASTNode *newNode(NodeKind kind) {
    ASTNode *node = (ASTNode*)calloc(1, sizeof(ASTNode));
    node->kind = kind;
    node->next = NULL;
    return node;
}

ASTNode *newIntLit(int val) {
    ASTNode *node = newNode(AST_INTLIT);
    node->u.ival = val;
    return node;
}

ASTNode *newIdent(char *s) {
    ASTNode *node = newNode(AST_IDENT);
    node->u.sval = s;
    return node;
}

ASTNode *newBinOp(OpKind op, ASTNode *l, ASTNode *r) {
    ASTNode *node = newNode(AST_BINOP);
    node->u.opr.op = op;
    node->u.opr.left = l;
    node->u.opr.right = r;
    return node;
}

ASTNode *newUnaryOp(ASTNode *expr) {
    ASTNode *node = newNode(AST_UNOP);
    node->u.opr.op = OP_UNARY_MINUS;
    node->u.opr.left = expr;
    node->u.opr.right = NULL;
    return node;
}

ASTNode *newDecl(char *var, ASTNode *expr) {
    ASTNode *node = newNode(AST_DECL);
    node->u.varStmt.varName = var;
    node->u.varStmt.expr = expr;
    return node;
}

ASTNode *newAssign(char *var, ASTNode *expr) {
    ASTNode *node = newNode(AST_ASSIGN);
    node->u.varStmt.varName = var;
    node->u.varStmt.expr = expr;
    return node;
}

ASTNode *newExprStmt(ASTNode *expr) {
    ASTNode *node = newNode(AST_EXPRSTMT);
    node->u.child = expr;
    return node;
}

ASTNode *newIf(ASTNode *cond, ASTNode *ifBlk, ASTNode *elseBlk) {
    ASTNode *node = newNode(AST_IF);
    node->u.ifStmt.cond = cond;
    node->u.ifStmt.ifBlock = ifBlk;
    node->u.ifStmt.elseBlock = elseBlk;
    return node;
}

ASTNode *newWhile(ASTNode *cond, ASTNode *body) {
    ASTNode *node = newNode(AST_WHILE);
    node->u.whileStmt.cond = cond;
    node->u.whileStmt.body = body;
    return node;
}

ASTNode *newPrint(char *var) {
    ASTNode *node = newNode(AST_PRINT);
    node->u.printVar = var;
    return node;
}

ASTNode *newBlock(ASTNode *stmtlist) {
    ASTNode *node = newNode(AST_BLOCK);
    node->u.child = stmtlist;
    return node;
}

/* 串联多条语句为一条 STMTLIST */
ASTNode *newStmtList(ASTNode *first, ASTNode *rest) {
    ASTNode *node = newNode(AST_STMTLIST);
    if (!first) {
        node->u.child = rest;
    } else {
        ASTNode *p = first;
        while (p->next) p = p->next;
        p->next = rest;
        node->u.child = first;
    }
    return node;
}

/* 条件表达式 */
ASTNode *newCondExpr(OpKind op, ASTNode *l, ASTNode *r) {
    ASTNode *node = newNode(AST_CONDEXPR);
    node->u.opr.op = op;
    node->u.opr.left = l;
    node->u.opr.right = r;
    return node;
}

/* ========== 变量表操作 ========== */
void setVarVal(const char *name, int value) {
    int idx = getVarIndex(name);
    if (idx == -1) {
        strcpy(vars[var_count].name, name);
        vars[var_count].value = value;
        var_count++;
    } else {
        vars[idx].value = value;
    }
}

int getVarVal(const char *name) {
    int idx = getVarIndex(name);
    if (idx == -1) {
        fprintf(stderr, "错误：变量 '%s' 未定义\n", name);
        exit(1);
    }
    return vars[idx].value;
}

/* ========== 解释执行逻辑 ========== */
int evalExpr(ASTNode *node);
void interpret(ASTNode *node);

int evalExpr(ASTNode *node) {
    if (!node) return 0;
    switch (node->kind) {
    case AST_INTLIT:
        return node->u.ival;
    case AST_IDENT:
        return getVarVal(node->u.sval);
    case AST_BINOP: {
        int lv = evalExpr(node->u.opr.left);
        int rv = evalExpr(node->u.opr.right);
        switch (node->u.opr.op) {
            case OP_PLUS:  return lv + rv;
            case OP_MINUS: return lv - rv;
            case OP_MULT:  return lv * rv;
            case OP_DIV:
                if (rv == 0) {
                    fprintf(stderr, "错误：除以 0\n");
                    exit(1);
                }
                return lv / rv;
            default:
                fprintf(stderr, "evalExpr: 未知二元操作 %d\n", node->u.opr.op);
                exit(1);
        }
    }
    case AST_UNOP: {
        /* 一元负号 */
        int v = evalExpr(node->u.opr.left);
        return -v;
    }
    case AST_CONDEXPR: {
        int lv = evalExpr(node->u.opr.left);
        int rv = evalExpr(node->u.opr.right);
        switch (node->u.opr.op) {
            case OP_COMP_EQ: return (lv == rv);
            case OP_COMP_NE: return (lv != rv);
            case OP_COMP_LT: return (lv <  rv);
            case OP_COMP_GT: return (lv >  rv);
            case OP_COMP_LE: return (lv <= rv);
            case OP_COMP_GE: return (lv >= rv);
            default:
                fprintf(stderr, "evalExpr: 未知比较操作 %d\n", node->u.opr.op);
                exit(1);
        }
    }
    default:
        fprintf(stderr, "evalExpr: 不支持 kind=%d\n", node->kind);
        exit(1);
    }
}

void interpret(ASTNode *node) {
    if (!node) return;

    switch (node->kind) {
    case AST_PROGRAM:
    case AST_STMTLIST: {
        ASTNode *p = node->u.child;
        while (p) {
            interpret(p);
            p = p->next;
        }
        break;
    }
    case AST_DECL: {
        int val = evalExpr(node->u.varStmt.expr);
        setVarVal(node->u.varStmt.varName, val);
        printf("声明并赋值: %s = %d\n", node->u.varStmt.varName, val);
        break;
    }
    case AST_ASSIGN: {
        int val = evalExpr(node->u.varStmt.expr);
        setVarVal(node->u.varStmt.varName, val);
        printf("赋值: %s = %d\n", node->u.varStmt.varName, val);
        break;
    }
    case AST_EXPRSTMT: {
        int val = evalExpr(node->u.child);
        printf("表达式计算结果: %d\n", val);
        break;
    }
    case AST_IF: {
        int c = evalExpr(node->u.ifStmt.cond);
        if (c) interpret(node->u.ifStmt.ifBlock);
        else   interpret(node->u.ifStmt.elseBlock);
        break;
    }
    case AST_WHILE: {
        while (evalExpr(node->u.whileStmt.cond)) {
            interpret(node->u.whileStmt.body);
        }
        break;
    }
    case AST_PRINT: {
        int val = getVarVal(node->u.printVar);
        printf("%s = %d\n", node->u.printVar, val);
        break;
    }
    case AST_BLOCK: {
        ASTNode *p = node->u.child;
        while (p) {
            interpret(p);
            p = p->next;
        }
        break;
    }
    default:
        fprintf(stderr, "interpret: 不支持节点 kind=%d\n", node->kind);
        exit(1);
    }
}

%}  /* 这里一定要与最开头的 %{ 成对匹配! */

/* -------------------- Bison 声明区域 (prologue 结束后) -------------------- */

/* 声明语义类型 */
%union {
    int num;              /* 对于 INT、COMP 等 */
    char *id;            /* 对于 IDENT */
    struct ASTNode *node;/* 对于各非终结符 */
}

/* token 声明 */
%token <num> INT
%token <id> IDENT
%token DECINT IF ELSE WHILE PRINTF EGALE PV PLUS MOINS MULT DIV OP CP OB CB
%token <num> COMP

/* 非终结符类型声明 */
%type <node> Program StmtList Stmt Declaration Assignment ExpressionStmt IfStmt WhileStmt PrintStmt Block
%type <node> expression condition_expr

/* 优先级 */
%nonassoc UMINUS
%left PLUS MOINS
%left MULT DIV
%nonassoc THEN
%right ELSE

/* 程序入口 */
%start Program

%%  /* -------------------- Grammar rules 开始 -------------------- */

/* 整个程序由若干语句列表组成 */
Program:
    StmtList
    {
        ASTNode *root = newNode(AST_PROGRAM);
        root->u.child = $1;
        /* 构造完 AST 后统一执行 */
        interpret(root);
        printf("解析结束（到达EOF或无更多输入）。\n");
    }
    ;

/* 语句列表：允许空 或 多条语句串联 */
StmtList:
    /* 空 => 返回NULL */
    {
        $$ = NULL;
    }
  | StmtList Stmt
    {
        /* 将 $2 接到 $1 链表末尾 */
        if (!$1) {
            $$ = $2;
        } else {
            ASTNode *p = $1;
            while (p->next) p = p->next;
            p->next = $2;
            $$ = $1;
        }
    }
    ;

/* 单条语句 */
Stmt:
      Declaration
    | Assignment
    | ExpressionStmt
    | IfStmt
    | WhileStmt
    | PrintStmt
    ;

/* 声明语句: int x=expr; */
Declaration:
    DECINT IDENT EGALE expression PV
    {
        $$ = newDecl($2, $4);
    }
    ;

/* 赋值语句: x=expr; */
Assignment:
    IDENT EGALE expression PV
    {
        $$ = newAssign($1, $3);
    }
    ;

/* 表达式语句: expr; */
ExpressionStmt:
    expression PV
    {
        $$ = newExprStmt($1);
    }
    ;

/* if(cond){...}[else{...}] */
IfStmt:
      IF OP condition_expr CP Block %prec THEN
      {
          $$ = newIf($3, $5, NULL);
      }
    | IF OP condition_expr CP Block ELSE Block
      {
          $$ = newIf($3, $5, $7);
      }
    ;

/* while(cond){...} */
WhileStmt:
    WHILE OP condition_expr CP Block
    {
        $$ = newWhile($3, $5);
    }
    ;

/* printf(x); */
PrintStmt:
    PRINTF OP IDENT CP PV
    {
        $$ = newPrint($3);
    }
    ;

/* 块： { StmtList } => AST_BLOCK */
Block:
    OB StmtList CB
    {
        $$ = newBlock($2);
    }
    ;

/* if/while 使用的条件表达式：expr COMP expr */
condition_expr:
    expression COMP expression
    {
        OpKind op;
        switch ($2) {
            case 0: op = OP_COMP_EQ; break;
            case 1: op = OP_COMP_NE; break;
            case 2: op = OP_COMP_LT; break;
            case 3: op = OP_COMP_GT; break;
            case 4: op = OP_COMP_LE; break;
            case 5: op = OP_COMP_GE; break;
        }
        $$ = newCondExpr(op, $1, $3);
    }
    ;

/* 一般表达式：支持整数、变量、加减乘除、一元负号、括号 */
expression:
      INT { $$ = newIntLit($1); }
    | IDENT { $$ = newIdent($1); }
    | expression PLUS expression { $$ = newBinOp(OP_PLUS, $1, $3); }
    | expression MOINS expression { $$ = newBinOp(OP_MINUS, $1, $3); }
    | expression MULT expression { $$ = newBinOp(OP_MULT, $1, $3); }
    | expression DIV expression  { $$ = newBinOp(OP_DIV, $1, $3); }
    | OP expression CP          { $$ = $2; }
    | MOINS expression %prec UMINUS { $$ = newUnaryOp($2); }
    ;

%%  /* ---------------- Grammar rules 结束 ----------------- */

/* 这里可以放结尾的 user code，如 main() 或 yyerror() */

int yyerror(const char *s) {
    fprintf(stderr, "语法错误: %s\n", s);
    exit(1);
}

int main() {
    yyparse();
    return 0;
}
