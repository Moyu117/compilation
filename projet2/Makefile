# 目标可执行文件名
TARGET = projet

# 源文件
LEX_SRC = lex.l
YACC_SRC = yacc.y

# Bison/Flex 生成的文件
YACC_C = y.tab.c
YACC_H = y.tab.h
LEX_C = lex.yy.c

# 默认规则：生成可执行文件
all: $(TARGET)

# 链接生成最终可执行文件
$(TARGET): $(YACC_C) $(LEX_C)
	gcc $(YACC_C) $(LEX_C) -o $(TARGET) -ll
	@echo "编译完成！运行 ./${TARGET}"

$(YACC_C) $(YACC_H): $(YACC_SRC)
	bison -d -o y.tab.c $(YACC_SRC)
	@echo "YACC 解析完成"


# 再用 Flex 生成 lex.yy.c，需要 y.tab.h 中的 token 定义
$(LEX_C): $(LEX_SRC) $(YACC_H)
	flex $(LEX_SRC)
	@echo "LEX 解析完成"

# 测试运行
run: all
	./$(TARGET)

# 清理
clean:
	rm -f $(TARGET) $(YACC_C) $(YACC_H) $(LEX_C)
	@echo "清理完成"
