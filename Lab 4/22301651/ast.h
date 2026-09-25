#ifndef AST_H
#define AST_H

#include <iostream>
#include <vector>
#include <string>
#include <fstream>
#include <map>

using namespace std;

class ASTNode {
public:
    virtual ~ASTNode() {}
    virtual string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp, int& temp_count, int& label_count) const = 0;
};

// Expression node types

class ExprNode : public ASTNode {
protected:
    string node_type; // Type information (int, float, void, etc.)
public:
    ExprNode(string type) : node_type(type) {}
    virtual string get_type() const { return node_type; }
};

// Variable node (for ID references)

class VarNode : public ExprNode {
private:
    string name;
    ExprNode* index; // For array access, nullptr for simple variables

public:
    VarNode(string name, string type, ExprNode* idx = nullptr)
        : ExprNode(type), name(name), index(idx) {}
    
    ~VarNode() { if(index) delete index; }
    
    bool has_index() const { return index != nullptr; }
    
    string generate_index_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                              int& temp_count, int& label_count) const {
        if (!index) {
            return "";
        }

        return index->generate_code(outcode, symbol_to_temp, temp_count, label_count);
    }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        if (!has_index()) {
            auto it = symbol_to_temp.find(name);
            if (it != symbol_to_temp.end()) {
                temp_count++;
                return it->second;
            }
        }

        string temp = "t" + to_string(temp_count++);

        if (has_index()) {
            string idx_temp = generate_index_code(outcode, symbol_to_temp, temp_count, label_count);
            outcode << temp << " = " << name << "[" << idx_temp << "]" << endl;
        } else {
            outcode << temp << " = " << name << endl;
            symbol_to_temp[name] = temp;
        }

        return temp;
    }
    
    string get_name() const { return name; }
};

// Constant node

class ConstNode : public ExprNode {
private:
    string value;

public:
    ConstNode(string val, string type) : ExprNode(type), value(val) {}
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        string temp = "t" + to_string(temp_count++);
        outcode << temp << " = " << value << endl;
        return temp;
    }
};

// Binary operation node

class BinaryOpNode : public ExprNode {
private:
    string op;
    ExprNode* left;
    ExprNode* right;

public:
    BinaryOpNode(string op, ExprNode* left, ExprNode* right, string result_type)
        : ExprNode(result_type), op(op), left(left), right(right) {}
    
    ~BinaryOpNode() {
        delete left;
        delete right;
    }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        string left_temp = left->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        string right_temp = right->generate_code(outcode, symbol_to_temp, temp_count, label_count);

        string result_temp = "t" + to_string(temp_count++);
        outcode << result_temp << " = " << left_temp << " " << op << " " << right_temp << endl;

        return result_temp;
    }
};

// Unary operation node

class UnaryOpNode : public ExprNode {
private:
    string op;
    ExprNode* expr;

public:
    UnaryOpNode(string op, ExprNode* expr, string result_type)
        : ExprNode(result_type), op(op), expr(expr) {}
    
    ~UnaryOpNode() { delete expr; }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        string expr_temp = expr->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        string result_temp = "t" + to_string(temp_count++);

        if (op == "+") {
            outcode << result_temp << " = " << expr_temp << endl;
        } else {
            outcode << result_temp << " = " << op << expr_temp << endl;
        }

        return result_temp;
    }
};

// Assignment node

class AssignNode : public ExprNode {
private:
    VarNode* lhs;
    ExprNode* rhs;

public:
    AssignNode(VarNode* lhs, ExprNode* rhs, string result_type)
        : ExprNode(result_type), lhs(lhs), rhs(rhs) {}
    
    ~AssignNode() {
        delete lhs;
        delete rhs;
    }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        string rhs_temp = rhs->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        string lhs_name = lhs->get_name();

        if (lhs->has_index()) {
            string idx_temp = lhs->generate_index_code(outcode, symbol_to_temp, temp_count, label_count);
            outcode << lhs_name << "[" << idx_temp << "] = " << rhs_temp << endl;
        } else {
            outcode << lhs_name << " = " << rhs_temp << endl;
        }
        if (dynamic_cast<const ConstNode*>(rhs) || dynamic_cast<const VarNode*>(rhs)) {
            symbol_to_temp.erase(lhs_name);
        } else {
            symbol_to_temp[lhs_name] = rhs_temp;
        }
        return rhs_temp;
    }
};

// Statement node types

class StmtNode : public ASTNode {
public:
    virtual string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                                int& temp_count, int& label_count) const = 0;
};

// Expression statement node

class ExprStmtNode : public StmtNode {
private:
    ExprNode* expr;

public:
    ExprStmtNode(ExprNode* e) : expr(e) {}
    ~ExprStmtNode() { if(expr) delete expr; }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        if (!expr) {
            return "";
        }

        return expr->generate_code(outcode, symbol_to_temp, temp_count, label_count);
    }
};

// Block (compound statement) node

class BlockNode : public StmtNode {
private:
    vector<StmtNode*> statements;

public:
    ~BlockNode() {
        for (auto stmt : statements) {
            delete stmt;
        }
    }
    
    void add_statement(StmtNode* stmt) {
        if (stmt) statements.push_back(stmt);
    }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        for (size_t i = 0; i < statements.size(); i++) {
            if (statements[i]) {
                statements[i]->generate_code(outcode, symbol_to_temp, temp_count, label_count);
            }
        }

        return "";
    }
};

// If statement node

class IfNode : public StmtNode {
private:
    ExprNode* condition;
    StmtNode* then_block;
    StmtNode* else_block; // nullptr if no else part

public:
    IfNode(ExprNode* cond, StmtNode* then_stmt, StmtNode* else_stmt = nullptr)
        : condition(cond), then_block(then_stmt), else_block(else_stmt) {}
    
    ~IfNode() {
        delete condition;
        delete then_block;
        if (else_block) delete else_block;
    }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        string cond_temp = condition->generate_code(outcode, symbol_to_temp, temp_count, label_count);

        string then_label = "L" + to_string(label_count++);
        string else_label = "L" + to_string(label_count++);
        string end_label = "L" + to_string(label_count++);

        outcode << "if " << cond_temp << " goto " << then_label << endl;
        outcode << "goto " << else_label << endl;

        outcode << then_label << ":" << endl;
        then_block->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        outcode << "goto " << end_label << endl;

        outcode << else_label << ":" << endl;
        if (else_block) {
            else_block->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        }

        outcode << end_label << ":" << endl;
        return "";
    }
};

// While statement node

class WhileNode : public StmtNode {
private:
    ExprNode* condition;
    StmtNode* body;

public:
    WhileNode(ExprNode* cond, StmtNode* body_stmt)
        : condition(cond), body(body_stmt) {}
    
    ~WhileNode() {
        delete condition;
        delete body;
    }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        string start_label = "L" + to_string(label_count++);
        string body_label = "L" + to_string(label_count++);
        string end_label = "L" + to_string(label_count++);

        outcode << start_label << ":" << endl;
        string cond_temp = condition->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        outcode << "if " << cond_temp << " goto " << body_label << endl;
        outcode << "goto " << end_label << endl;

        outcode << body_label << ":" << endl;
        body->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        outcode << "goto " << start_label << endl;

        outcode << end_label << ":" << endl;
        return "";
    }
};

// For statement node

class ForNode : public StmtNode {
private:
    ExprNode* init;
    ExprNode* condition;
    ExprNode* update;
    StmtNode* body;

public:
    ForNode(ExprNode* init_expr, ExprNode* cond_expr, ExprNode* update_expr, StmtNode* body_stmt)
        : init(init_expr), condition(cond_expr), update(update_expr), body(body_stmt) {}
    
    ~ForNode() {
        if (init) delete init;
        if (condition) delete condition;
        if (update) delete update;
        delete body;
    }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        if (init) {
            init->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        }

        string start_label = "L" + to_string(label_count++);
        string body_label = "L" + to_string(label_count++);
        string end_label = "L" + to_string(label_count++);

        outcode << start_label << ":" << endl;
        symbol_to_temp.clear();

        string cond_temp = "1";
        if (condition) {
            cond_temp = condition->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        }

        outcode << "if " << cond_temp << " goto " << body_label << endl;
        outcode << "goto " << end_label << endl;

        outcode << body_label << ":" << endl;
        body->generate_code(outcode, symbol_to_temp, temp_count, label_count);

        if (update) {
            update->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        }

        outcode << "goto " << start_label << endl;
        outcode << end_label << ":" << endl;

        return "";
    }
};

// Return statement node

class ReturnNode : public StmtNode {
private:
    ExprNode* expr;

public:
    ReturnNode(ExprNode* e) : expr(e) {}
    ~ReturnNode() { if (expr) delete expr; }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        if (expr) {
            string expr_temp = expr->generate_code(outcode, symbol_to_temp, temp_count, label_count);
            outcode << "return " << expr_temp << endl;
        } else {
            outcode << "return" << endl;
        }

        return "";
    }
};

// Declaration node

class DeclNode : public StmtNode {
private:
    string type;
    vector<pair<string, int>> vars; // Variable name and array size (0 for regular vars)

public:
    DeclNode(string t) : type(t) {}
    
    void add_var(string name, int array_size = 0) {
        vars.push_back(make_pair(name, array_size));
    }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        for (size_t i = 0; i < vars.size(); i++) {
            if (vars[i].second > 0) {
                outcode << "// Declaration: " << type << " " << vars[i].first << "[" << vars[i].second << "]" << endl;
            } else {
                outcode << "// Declaration: " << type << " " << vars[i].first << endl;
            }
        }

        return "";
    }
    
    string get_type() const { return type; }
    const vector<pair<string, int>>& get_vars() const { return vars; }
};

// Function declaration node

class FuncDeclNode : public ASTNode {
private:
    string return_type;
    string name;
    vector<pair<string, string>> params; // Parameter type and name
    BlockNode* body;

public:
    FuncDeclNode(string ret_type, string n) : return_type(ret_type), name(n), body(nullptr) {}
    ~FuncDeclNode() { if (body) delete body; }
    
    void add_param(string type, string name) {
        params.push_back(make_pair(type, name));
    }
    
    void set_body(BlockNode* b) {
        body = b;
    }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        outcode << endl;
        outcode << "// Function: " << return_type << " " << name << "(";

        for (size_t i = 0; i < params.size(); i++) {
            outcode << params[i].first << " " << params[i].second;
            if (i + 1 < params.size()) {
                outcode << ", ";
            }
        }

        outcode << ")" << endl;

        if (body) {
            symbol_to_temp.clear();
            body->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        }

        return "";
    }
};

// Helper class for function arguments

class ArgumentsNode : public ASTNode {
private:
    vector<ExprNode*> args;

public:
    ~ArgumentsNode() {
        // Don't delete args here - they'll be transferred to FuncCallNode
    }
    
    void add_argument(ExprNode* arg) {
        if (arg) args.push_back(arg);
    }
    
    ExprNode* get_argument(int index) const {
        if (index >= 0 && index < args.size()) {
            return args[index];
        }
        return nullptr;
    }
    
    size_t size() const {
        return args.size();
    }
    
    const vector<ExprNode*>& get_arguments() const {
        return args;
    }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        // This node doesn't generate code directly
        return "";
    }
};

// Function call node

class FuncCallNode : public ExprNode {
private:
    string func_name;
    vector<ExprNode*> arguments;

public:
    FuncCallNode(string name, string result_type)
        : ExprNode(result_type), func_name(name) {}
    
    ~FuncCallNode() {
        for (auto arg : arguments) {
            delete arg;
        }
    }
    
    void add_argument(ExprNode* arg) {
        if (arg) arguments.push_back(arg);
    }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        for (size_t i = 0; i < arguments.size(); i++) {
            string arg_temp = arguments[i]->generate_code(outcode, symbol_to_temp, temp_count, label_count);
            outcode << "param " << arg_temp << endl;
        }

        string result_temp = "t" + to_string(temp_count++);
        outcode << result_temp << " = call " << func_name << ", " << arguments.size() << endl;

        return result_temp;
    }
};

// Program node (root of AST)

class ProgramNode : public ASTNode {
private:
    vector<ASTNode*> units;

public:
    ~ProgramNode() {
        for (auto unit : units) {
            delete unit;
        }
    }
    
    void add_unit(ASTNode* unit) {
        if (unit) units.push_back(unit);
    }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        for (size_t i = 0; i < units.size(); i++) {
            if (units[i]) {
                units[i]->generate_code(outcode, symbol_to_temp, temp_count, label_count);
            }
        }

        return "";
    }
};

#endif // AST_H