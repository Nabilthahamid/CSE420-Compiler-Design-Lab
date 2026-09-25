%{

#include "symbol_table.h"

#define YYSTYPE symbol_info*

extern FILE *yyin;
int yyparse(void);
int yylex(void);
extern YYSTYPE yylval;

symbol_table *sym_table; 
// It stores declared variables, arrays, functions, and their scope information
string current_var_type;
vector<symbol_info*> current_param_list;
vector<string> declaration_errors;
string active_function;

int lines = 1;
int error_count = 0;

ofstream outlog;
ofstream outerror;

void semantic_error(const string& message)
{
	outlog << "At line no: " << lines << " " << message << endl << endl;
	outerror << "At line no: " << lines << " " << message << endl << endl;
	error_count++;
}

string parameter_type(const string& detail)
{
	size_t blank = detail.find(' ');
	return blank == string::npos ? detail : detail.substr(0, blank);
}

string arithmetic_type(const string& left, const string& right)
{
	if (left == "error" || right == "error") return "error";
	if (left == "void" || right == "void") return "error";
	return (left == "float" || right == "float") ? "float" : "int";
}

bool literal_zero(const string& text)
{
	string value_text = text;
	while (value_text.size() >= 2 && value_text.front() == '(' && value_text.back() == ')') {
		int depth = 0;
		bool outer_pair_wraps_all = true;
		for (size_t i = 0; i < value_text.size(); i++) {
			if (value_text[i] == '(') depth++;
			else if (value_text[i] == ')') depth--;
			if (depth == 0 && i + 1 < value_text.size()) {
				outer_pair_wraps_all = false;
				break;
			}
			if (depth < 0) {
				outer_pair_wraps_all = false;
				break;
			}
		}
		if (!outer_pair_wraps_all || depth != 0) break;
		value_text = value_text.substr(1, value_text.size() - 2);
	}
	char *end = nullptr;
	double value = strtod(value_text.c_str(), &end);
	return end != value_text.c_str() && *end == '\0' && value == 0.0;
}

void yyerror(char *s)
{
	semantic_error(s);
}

%}

%token IF ELSE FOR WHILE DO BREAK INT CHAR FLOAT DOUBLE VOID RETURN SWITCH CASE DEFAULT CONTINUE PRINTLN ADDOP MULOP INCOP DECOP RELOP ASSIGNOP LOGICOP NOT LPAREN RPAREN LCURL RCURL LTHIRD RTHIRD COMMA SEMICOLON CONST_INT CONST_FLOAT ID

%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE

%%

start : program
	{
		outlog<<"At line no: "<<lines<<" start : program "<<endl<<endl;
		outlog<<"Symbol Table"<<endl<<endl;
		sym_table->print_all_scopes(outlog);
	}
	;

program : program unit
	{
		outlog<<"At line no: "<<lines<<" program : program unit "<<endl<<endl;
		outlog<<$1->get_name()+"\n"+$2->get_name()<<endl<<endl;
		
		$$ = new symbol_info($1->get_name()+"\n"+$2->get_name(),"program");
	}
	| unit
	{
		outlog<<"At line no: "<<lines<<" program : unit "<<endl<<endl;
		outlog<<$1->get_name()<<endl<<endl;
		
		$$ = new symbol_info($1->get_name(),"program");
	}
	;

unit : var_declaration
	 {
		outlog<<"At line no: "<<lines<<" unit : var_declaration "<<endl<<endl;
		outlog<<$1->get_name()<<endl<<endl;
		
		$$ = new symbol_info($1->get_name(),"unit");
	 }
     | func_definition
     {
		outlog<<"At line no: "<<lines<<" unit : func_definition "<<endl<<endl;
		outlog<<$1->get_name()<<endl<<endl;
		
		$$ = new symbol_info($1->get_name(),"unit");
	 }
     ;

func_definition : type_specifier function_name LPAREN { current_param_list.clear(); } parameter_list RPAREN 
		{
			$2->set_symbol_kind("function");
			$2->set_data_type($1->get_name());
			vector<string> param_details;
			for (auto p : current_param_list) {
				param_details.push_back(p->get_data_type() + " " + p->get_name());
			}
			$2->set_param_details(param_details);
			if (sym_table->lookup_current_scope($2->get_name()))
				semantic_error("Multiple declaration of function " + $2->get_name());
			else
				sym_table->insert($2, outlog);
		} compound_statement
	{	
		outlog<<"At line no: "<<lines<<" func_definition : type_specifier ID LPAREN parameter_list RPAREN compound_statement "<<endl<<endl;
		outlog<<$1->get_name()<<" "<<$2->get_name()<<"("+$5->get_name()+")\n"<<$8->get_name()<<endl<<endl;
		
		$$ = new symbol_info($1->get_name()+" "+$2->get_name()+"("+$5->get_name()+")\n"+$8->get_name(),"func_def");	
	}
	| type_specifier function_name LPAREN { current_param_list.clear(); } RPAREN 
		{
			$2->set_symbol_kind("function");
			$2->set_data_type($1->get_name());
			$2->set_param_details({});
			if (sym_table->lookup_current_scope($2->get_name()))
				semantic_error("Multiple declaration of function " + $2->get_name());
			else
				sym_table->insert($2, outlog);
		} compound_statement
	{
		outlog<<"At line no: "<<lines<<" func_definition : type_specifier ID LPAREN RPAREN compound_statement "<<endl<<endl;
		outlog<<$1->get_name()<<" "<<$2->get_name()<<"()\n"<<$7->get_name()<<endl<<endl;
		
		$$ = new symbol_info($1->get_name()+" "+$2->get_name()+"()\n"+$7->get_name(),"func_def");	
	}
	;

function_name : ID
	{
		active_function = $1->get_name();
		$$ = $1;
	}
	;

parameter_list : parameter_list COMMA type_specifier ID
		{
			outlog<<"At line no: "<<lines<<" parameter_list : parameter_list COMMA type_specifier ID "<<endl<<endl;
			outlog<<$1->get_name()<<","<<$3->get_name()<<" "<<$4->get_name()<<endl<<endl;
					
			$$ = new symbol_info($1->get_name()+","+$3->get_name()+" "+$4->get_name(),"param_list");
			
			$4->set_symbol_kind("variable");
			$4->set_data_type($3->get_name());
			for (auto parameter : current_param_list) {
				if (parameter->get_name() == $4->get_name()) {
					semantic_error("Multiple declaration of variable " + $4->get_name() +
						" in parameter of " + active_function);
					break;
				}
			}
			current_param_list.push_back($4);
		}
		| parameter_list COMMA type_specifier
		{
			outlog<<"At line no: "<<lines<<" parameter_list : parameter_list COMMA type_specifier "<<endl<<endl;
			outlog<<$1->get_name()<<","<<$3->get_name()<<endl<<endl;
			
			$$ = new symbol_info($1->get_name()+","+$3->get_name(),"param_list");
		}
 		| type_specifier ID
 		{
			outlog<<"At line no: "<<lines<<" parameter_list : type_specifier ID "<<endl<<endl;
			outlog<<$1->get_name()<<" "<<$2->get_name()<<endl<<endl;
			
			$$ = new symbol_info($1->get_name()+" "+$2->get_name(),"param_list");
			
			$2->set_symbol_kind("variable");
			$2->set_data_type($1->get_name());
			current_param_list.push_back($2);
		}
		| type_specifier
		{
			outlog<<"At line no: "<<lines<<" parameter_list : type_specifier "<<endl<<endl;
			outlog<<$1->get_name()<<endl<<endl;
			
			$$ = new symbol_info($1->get_name(),"param_list");
		}
 		;

compound_statement : LCURL { 
			sym_table->enter_scope(outlog);
			for (auto param : current_param_list) {
				sym_table->insert(param, outlog);
			}
			current_param_list.clear();
		} statements RCURL
		{ 
 			outlog<<"At line no: "<<lines<<" compound_statement : LCURL statements RCURL "<<endl<<endl;
			outlog<<"{\n"+$3->get_name()+"\n}"<<endl<<endl;
			
			$$ = new symbol_info("{\n"+$3->get_name()+"\n}","comp_stmnt");
			
			sym_table->print_all_scopes(outlog);   // Print full symbol table before exiting
			sym_table->exit_scope(outlog);
		}
		| LCURL { 
			sym_table->enter_scope(outlog);
			for (auto param : current_param_list) {
				sym_table->insert(param, outlog);
			}
			current_param_list.clear();
		} RCURL
		{ 
 			outlog<<"At line no: "<<lines<<" compound_statement : LCURL RCURL "<<endl<<endl;
			outlog<<"{\n}"<<endl<<endl;
			
			$$ = new symbol_info("{\n}","comp_stmnt");
			
			sym_table->print_all_scopes(outlog);   // Print full symbol table before exiting
			sym_table->exit_scope(outlog);
		}
		;
		    
var_declaration : type_specifier declaration_list SEMICOLON
		 {
			outlog<<"At line no: "<<lines<<" var_declaration : type_specifier declaration_list SEMICOLON "<<endl<<endl;
			outlog<<$1->get_name()<<" "<<$2->get_name()<<";"<<endl<<endl;

			if ($1->get_name() == "void")
				semantic_error("Variable type cannot be void");
			for (const string& message : declaration_errors)
				semantic_error(message);
			declaration_errors.clear();
			
			$$ = new symbol_info($1->get_name()+" "+$2->get_name()+";","var_dec");
		 }
 		 ;

type_specifier : INT
		{
			outlog<<"At line no: "<<lines<<" type_specifier : INT "<<endl<<endl;
			outlog<<"int"<<endl<<endl;
			
			$$ = new symbol_info("int","type");
			current_var_type = "int";
	    }
 		| FLOAT
 		{
			outlog<<"At line no: "<<lines<<" type_specifier : FLOAT "<<endl<<endl;
			outlog<<"float"<<endl<<endl;
			
			$$ = new symbol_info("float","type");
			current_var_type = "float";
	    }
 		| VOID
 		{
			outlog<<"At line no: "<<lines<<" type_specifier : VOID "<<endl<<endl;
			outlog<<"void"<<endl<<endl;
			
			$$ = new symbol_info("void","type");
			current_var_type = "void";
	    }
		| CHAR
 		{
			outlog<<"At line no: "<<lines<<" type_specifier : CHAR "<<endl<<endl;
			outlog<<"char"<<endl<<endl;
			
			$$ = new symbol_info("char","type");
			current_var_type = "char";
	    }
 		;

declaration_list : declaration_list COMMA ID
		  {
 		  	outlog<<"At line no: "<<lines<<" declaration_list : declaration_list COMMA ID "<<endl<<endl;
 		  	outlog<<$1->get_name()+","<<$3->get_name()<<endl<<endl;

			$$ = new symbol_info($1->get_name()+","+$3->get_name(),"decl_list");
			
			$3->set_symbol_kind("variable");
			$3->set_data_type(current_var_type == "void" ? "error" : current_var_type);
			if (!sym_table->insert($3, outlog))
				declaration_errors.push_back("Multiple declaration of variable " + $3->get_name());
 		  }
 		  | declaration_list COMMA ID LTHIRD CONST_INT RTHIRD
 		  {
 		  	outlog<<"At line no: "<<lines<<" declaration_list : declaration_list COMMA ID LTHIRD CONST_INT RTHIRD "<<endl<<endl;
 		  	outlog<<$1->get_name()+","<<$3->get_name()<<"["<<$5->get_name()<<"]"<<endl<<endl;

			$$ = new symbol_info($1->get_name()+","+$3->get_name()+"["+$5->get_name()+"]","decl_list");
			
			$3->set_symbol_kind("array");
			$3->set_data_type(current_var_type == "void" ? "error" : current_var_type);
			$3->set_array_size(atoi($5->get_name().c_str()));
			if (!sym_table->insert($3, outlog))
				declaration_errors.push_back("Multiple declaration of variable " + $3->get_name());
 		  }
 		  | ID
 		  {
 		  	outlog<<"At line no: "<<lines<<" declaration_list : ID "<<endl<<endl;
			outlog<<$1->get_name()<<endl<<endl;

			$$ = new symbol_info($1->get_name(),"decl_list");
			declaration_errors.clear();
			
			$1->set_symbol_kind("variable");
			$1->set_data_type(current_var_type == "void" ? "error" : current_var_type);
			if (!sym_table->insert($1, outlog))
				declaration_errors.push_back("Multiple declaration of variable " + $1->get_name());
 		  }
 		  | ID LTHIRD CONST_INT RTHIRD
 		  {
 		  	outlog<<"At line no: "<<lines<<" declaration_list : ID LTHIRD CONST_INT RTHIRD "<<endl<<endl;
			outlog<<$1->get_name()<<"["<<$3->get_name()<<"]"<<endl<<endl;

			$$ = new symbol_info($1->get_name()+"["+$3->get_name()+"]","decl_list");
			declaration_errors.clear();
			
			$1->set_symbol_kind("array");
			$1->set_data_type(current_var_type == "void" ? "error" : current_var_type);
			$1->set_array_size(atoi($3->get_name().c_str()));
			if (!sym_table->insert($1, outlog))
				declaration_errors.push_back("Multiple declaration of variable " + $1->get_name());
 		  }
 		  ;
 		  

statements : statement
	   {
	    	outlog<<"At line no: "<<lines<<" statements : statement "<<endl<<endl;
			outlog<<$1->get_name()<<endl<<endl;
			
			$$ = new symbol_info($1->get_name(),"stmnts");
	   }
	   | statements statement
	   {
	    	outlog<<"At line no: "<<lines<<" statements : statements statement "<<endl<<endl;
			outlog<<$1->get_name()<<"\n"<<$2->get_name()<<endl<<endl;
			
			$$ = new symbol_info($1->get_name()+"\n"+$2->get_name(),"stmnts");
	   }
	   ;
	   
statement : var_declaration
	  {
	    	outlog<<"At line no: "<<lines<<" statement : var_declaration "<<endl<<endl;
			outlog<<$1->get_name()<<endl<<endl;
			
			$$ = new symbol_info($1->get_name(),"stmnt");
	  }
	  | func_definition
	  {
	  		outlog<<"At line no: "<<lines<<" statement : func_definition "<<endl<<endl;
            outlog<<$1->get_name()<<endl<<endl;

            $$ = new symbol_info($1->get_name(),"stmnt");
	  		
	  }
	  | expression_statement
	  {
	    	outlog<<"At line no: "<<lines<<" statement : expression_statement "<<endl<<endl;
			outlog<<$1->get_name()<<endl<<endl;
			
			$$ = new symbol_info($1->get_name(),"stmnt");
	  }
	  | compound_statement
	  {
	    	outlog<<"At line no: "<<lines<<" statement : compound_statement "<<endl<<endl;
			outlog<<$1->get_name()<<endl<<endl;
			
			$$ = new symbol_info($1->get_name(),"stmnt");
	  }
	  | FOR LPAREN expression_statement expression_statement expression RPAREN statement
	  {
	    	outlog<<"At line no: "<<lines<<" statement : FOR LPAREN expression_statement expression_statement expression RPAREN statement "<<endl<<endl;
			outlog<<"for("<<$3->get_name()<<$4->get_name()<<$5->get_name()<<")\n"<<$7->get_name()<<endl<<endl;
			
			$$ = new symbol_info("for("+$3->get_name()+$4->get_name()+$5->get_name()+")\n"+$7->get_name(),"stmnt");
	  }
	  | IF LPAREN expression RPAREN statement %prec LOWER_THAN_ELSE
	  {
	    	outlog<<"At line no: "<<lines<<" statement : IF LPAREN expression RPAREN statement "<<endl<<endl;
			outlog<<"if("<<$3->get_name()<<")\n"<<$5->get_name()<<endl<<endl;
			
			$$ = new symbol_info("if("+$3->get_name()+")\n"+$5->get_name(),"stmnt");
	  }
	  | IF LPAREN expression RPAREN statement ELSE statement
	  {
	    	outlog<<"At line no: "<<lines<<" statement : IF LPAREN expression RPAREN statement ELSE statement "<<endl<<endl;
			outlog<<"if("<<$3->get_name()<<")\n"<<$5->get_name()<<"\nelse\n"<<$7->get_name()<<endl<<endl;
			
			$$ = new symbol_info("if("+$3->get_name()+")\n"+$5->get_name()+"\nelse\n"+$7->get_name(),"stmnt");
	  }
	  | WHILE LPAREN expression RPAREN statement
	  {
	    	outlog<<"At line no: "<<lines<<" statement : WHILE LPAREN expression RPAREN statement "<<endl<<endl;
			outlog<<"while("<<$3->get_name()<<")\n"<<$5->get_name()<<endl<<endl;
			
			$$ = new symbol_info("while("+$3->get_name()+")\n"+$5->get_name(),"stmnt");
	  }
	  | PRINTLN LPAREN ID RPAREN SEMICOLON
	  {
	    	outlog<<"At line no: "<<lines<<" statement : PRINTLN LPAREN ID RPAREN SEMICOLON "<<endl<<endl;
			outlog<<"printf("<<$3->get_name()<<");"<<endl<<endl; 
			if (!sym_table->lookup($3->get_name()))
				semantic_error("Undeclared variable " + $3->get_name());
			
			$$ = new symbol_info("printf("+$3->get_name()+");","stmnt");
	  }
	  | RETURN expression SEMICOLON
	  {
	    	outlog<<"At line no: "<<lines<<" statement : RETURN expression SEMICOLON "<<endl<<endl;
			outlog<<"return "<<$2->get_name()<<";"<<endl<<endl;
			if ($2->get_data_type() == "void")
				semantic_error("Void function used in expression");
			
			$$ = new symbol_info("return "+$2->get_name()+";","stmnt");
	  }
	  ;
	  
expression_statement : SEMICOLON
			{
				outlog<<"At line no: "<<lines<<" expression_statement : SEMICOLON "<<endl<<endl;
				outlog<<";"<<endl<<endl;
				
				$$ = new symbol_info(";","expr_stmt");
	        }			
			| expression SEMICOLON 
			{
				outlog<<"At line no: "<<lines<<" expression_statement : expression SEMICOLON "<<endl<<endl;
				outlog<<$1->get_name()<<";"<<endl<<endl;
				
				$$ = new symbol_info($1->get_name()+";","expr_stmt");
	        }
			;
	  
variable : ID 	
      {
	    outlog<<"At line no: "<<lines<<" variable : ID "<<endl<<endl;
		outlog<<$1->get_name()<<endl<<endl;
			
		$$ = new symbol_info($1->get_name(),"varbl");
		symbol_info *declared = 
		    sym_table->lookup($1->get_name());
		
		if (!declared) {
			semantic_error(
				"Undeclared variable " + $1->get_name()
			);
			
			$$->set_data_type("error");
		}
		else if (declared->get_symbol_kind() == "array") {
			semantic_error("Variable is of array type: " + $1->get_name());
			$$->set_data_type("error");
		}
		else {
			$$->set_data_type(declared->get_data_type());
			$$->set_symbol_kind(declared->get_symbol_kind());
		}
		
	 }	
	 | ID LTHIRD expression RTHIRD 
	 {
	 	outlog<<"At line no: "<<lines<<" variable : ID LTHIRD expression RTHIRD "<<endl<<endl;
		outlog<<$1->get_name()<<"["<<$3->get_name()<<"]"<<endl<<endl;
		
		$$ = new symbol_info($1->get_name()+"["+$3->get_name()+"]","varbl");
		symbol_info *declared = sym_table->lookup($1->get_name());
		if (!declared) {
			semantic_error("Undeclared variable " + $1->get_name());
			$$->set_data_type("error");
		}
		else if (declared->get_symbol_kind() != "array") {
			semantic_error("Variable is not of array type: " + $1->get_name());
			$$->set_data_type("error");
		}
		else {
			$$->set_data_type(declared->get_data_type());
		}
		if ($3->get_data_type() != "int" && $3->get_data_type() != "error")
			semantic_error("Array index is not of integer type: " + $1->get_name());
	 }
	 ;
	 
expression : logic_expression
	   {
	    	outlog<<"At line no: "<<lines<<" expression : logic_expression "<<endl<<endl;
			outlog<<$1->get_name()<<endl<<endl;
			
			$$ = new symbol_info($1->get_name(),"expr");
			$$->set_data_type($1->get_data_type());
	   }
	   | variable ASSIGNOP logic_expression 	
	   {
	    	outlog<<"At line no: "<<lines<<" expression : variable ASSIGNOP logic_expression "<<endl<<endl;
			outlog<<$1->get_name()<<"="<<$3->get_name()<<endl<<endl;
			string lhs = $1->get_data_type(), rhs = $3->get_data_type();
			if (lhs != "error" && rhs != "error") {
				if (lhs == "void" || rhs == "void")
					semantic_error("Void value used in assignment");
				else if (lhs == "int" && rhs == "float")
					semantic_error("Warning: Assignment of float value to integer variable");
				else if (lhs != rhs && !(lhs == "float" && rhs == "int"))
					semantic_error("Type mismatch in assignment");
			}

			$$ = new symbol_info($1->get_name()+"="+$3->get_name(),"expr");
			$$->set_data_type(lhs);
	   }
	   ;
			
logic_expression : rel_expression
	     {
	    	outlog<<"At line no: "<<lines<<" logic_expression : rel_expression "<<endl<<endl;
			outlog<<$1->get_name()<<endl<<endl;
			
			$$ = new symbol_info($1->get_name(),"lgc_expr");
			$$->set_data_type($1->get_data_type());
	     }	
		 | rel_expression LOGICOP rel_expression 
		 {
	    	outlog<<"At line no: "<<lines<<" logic_expression : rel_expression LOGICOP rel_expression "<<endl<<endl;
			outlog<<$1->get_name()<<$2->get_name()<<$3->get_name()<<endl<<endl;
			
			$$ = new symbol_info($1->get_name()+$2->get_name()+$3->get_name(),"lgc_expr");
			if ($1->get_data_type() == "void" || $3->get_data_type() == "void")
				semantic_error("Void value used with logical operator");
			$$->set_data_type("int");
	     }	
		 ;
			
rel_expression	: simple_expression
		{
	    	outlog<<"At line no: "<<lines<<" rel_expression : simple_expression "<<endl<<endl;
			outlog<<$1->get_name()<<endl<<endl;
			
			$$ = new symbol_info($1->get_name(),"rel_expr");
			$$->set_data_type($1->get_data_type());
	    }
		| simple_expression RELOP simple_expression
		{
	    	outlog<<"At line no: "<<lines<<" rel_expression : simple_expression RELOP simple_expression "<<endl<<endl;
			outlog<<$1->get_name()<<$2->get_name()<<$3->get_name()<<endl<<endl;
			
			$$ = new symbol_info($1->get_name()+$2->get_name()+$3->get_name(),"rel_expr");
			if ($1->get_data_type() == "void" || $3->get_data_type() == "void")
				semantic_error("Void value used with relational operator");
			$$->set_data_type("int");
	    }
		;
				
simple_expression : term
          {
	    	outlog<<"At line no: "<<lines<<" simple_expression : term "<<endl<<endl;
			outlog<<$1->get_name()<<endl<<endl;
			
			$$ = new symbol_info($1->get_name(),"simp_expr");
			$$->set_data_type($1->get_data_type());
			
	      }
		  | simple_expression ADDOP term 
		  {
	    	outlog<<"At line no: "<<lines<<" simple_expression : simple_expression ADDOP term "<<endl<<endl;
			outlog<<$1->get_name()<<$2->get_name()<<$3->get_name()<<endl<<endl;
			
			$$ = new symbol_info($1->get_name()+$2->get_name()+$3->get_name(),"simp_expr");
			if ($1->get_data_type() == "void" || $3->get_data_type() == "void")
				semantic_error("Void value used with arithmetic operator");
			$$->set_data_type(arithmetic_type($1->get_data_type(), $3->get_data_type()));
	      }
		  ;
					
term :	unary_expression
     {
	    	outlog<<"At line no: "<<lines<<" term : unary_expression "<<endl<<endl;
			outlog<<$1->get_name()<<endl<<endl;
			
			$$ = new symbol_info($1->get_name(),"term");
			$$->set_data_type($1->get_data_type());
			
	 }
     |  term MULOP unary_expression
     {
	    	outlog<<"At line no: "<<lines<<" term : term MULOP unary_expression "<<endl<<endl;
			outlog<<$1->get_name()<<$2->get_name()<<$3->get_name()<<endl<<endl;
			
			string op = $2->get_name();
			string result = arithmetic_type($1->get_data_type(), $3->get_data_type());
			if ($1->get_data_type() == "void" || $3->get_data_type() == "void")
				semantic_error("Void value used with arithmetic operator");
			else if (op == "%" && ($1->get_data_type() != "int" || $3->get_data_type() != "int")) {
				semantic_error("Operands of modulus must be integers");
				result = "error";
			}
			else if ((op == "%" || op == "/") && literal_zero($3->get_name()))
				semantic_error(op == "%" ? "Modulus by zero" : "Division by zero");
			$$ = new symbol_info($1->get_name()+op+$3->get_name(),"term");
			$$->set_data_type(result);
			
	 }
     ;

unary_expression : ADDOP unary_expression
		 {
	    	outlog<<"At line no: "<<lines<<" unary_expression : ADDOP unary_expression "<<endl<<endl;
			outlog<<$1->get_name()<<$2->get_name()<<endl<<endl;
			
		 	$$ = new symbol_info($1->get_name()+$2->get_name(),"un_expr");
			if ($2->get_data_type() == "void") {
				semantic_error("Void function used in expression");
				$$->set_data_type("error");
			}
			else
				$$->set_data_type($2->get_data_type());
	     }
		 | NOT unary_expression 
		 {
	    	outlog<<"At line no: "<<lines<<" unary_expression : NOT unary_expression "<<endl<<endl;
			outlog<<"!"<<$2->get_name()<<endl<<endl;
			
		 	$$ = new symbol_info("!"+$2->get_name(),"un_expr");
			if ($2->get_data_type() == "void") {
				semantic_error("Void function used in expression");
				$$->set_data_type("error");
			}
			else
				$$->set_data_type("int");
	     }
		 | factor 
		 {
	    	outlog<<"At line no: "<<lines<<" unary_expression : factor "<<endl<<endl;
			outlog<<$1->get_name()<<endl<<endl;
			
			$$ = new symbol_info($1->get_name(),"un_expr");
			$$->set_data_type($1->get_data_type());
	     }
		 ;
	
factor	: variable
    {
	    outlog<<"At line no: "<<lines<<" factor : variable "<<endl<<endl;
		outlog<<$1->get_name()<<endl<<endl;
			
		$$ = new symbol_info($1->get_name(),"fctr");
		$$->set_data_type($1->get_data_type());
	}
	| ID LPAREN argument_list RPAREN
	{
	    outlog<<"At line no: "<<lines<<" factor : ID LPAREN argument_list RPAREN "<<endl<<endl;
		outlog<<$1->get_name()<<"("<<$3->get_name()<<")"<<endl<<endl;

		$$ = new symbol_info($1->get_name()+"("+$3->get_name()+")","fctr");
		symbol_info *function = sym_table->lookup($1->get_name());
		if (!function) {
			semantic_error("Undeclared function: " + $1->get_name());
			$$->set_data_type("error");
		}
		else if (function->get_symbol_kind() != "function") {
			semantic_error($1->get_name() + " is not a function");
			$$->set_data_type("error");
		}
		else {
			const vector<string>& expected = function->get_param_details();
			const vector<string>& actual = $3->get_param_details();
			if (expected.size() != actual.size())
				semantic_error("Argument count mismatch in function call: " + $1->get_name());
			else {
				for (size_t i = 0; i < expected.size(); i++) {
					if (actual[i] != "error" && parameter_type(expected[i]) != actual[i])
						semantic_error("Argument " + to_string(i + 1) +
							" type mismatch in function call: " + $1->get_name());
				}
			}
			$$->set_data_type(function->get_data_type());
		}
	}
	| LPAREN expression RPAREN
	{
	   	outlog<<"At line no: "<<lines<<" factor : LPAREN expression RPAREN "<<endl<<endl;
		outlog<<"("<<$2->get_name()<<")"<<endl<<endl;
		
		$$ = new symbol_info("("+$2->get_name()+")","fctr");
		$$->set_data_type($2->get_data_type());
	}
	| CONST_INT 
	{
	    outlog<<"At line no: "<<lines<<" factor : CONST_INT "<<endl<<endl;
		outlog<<$1->get_name()<<endl<<endl;
			
		$$ = new symbol_info($1->get_name(),"fctr");
		$$->set_data_type("int");
	}
	| CONST_FLOAT
	{
	    outlog<<"At line no: "<<lines<<" factor : CONST_FLOAT "<<endl<<endl;
		outlog<<$1->get_name()<<endl<<endl;
			
		$$ = new symbol_info($1->get_name(),"fctr");
		$$->set_data_type("float");
	}
	| variable INCOP 
	{
	    outlog<<"At line no: "<<lines<<" factor : variable INCOP "<<endl<<endl;
		outlog<<$1->get_name()<<"++"<<endl<<endl;
			
		$$ = new symbol_info($1->get_name()+"++","fctr");
		$$->set_data_type($1->get_data_type());
	}
	| variable DECOP
	{
	    outlog<<"At line no: "<<lines<<" factor : variable DECOP "<<endl<<endl;
		outlog<<$1->get_name()<<"--"<<endl<<endl;
			
		$$ = new symbol_info($1->get_name()+"--","fctr");
		$$->set_data_type($1->get_data_type());
	}
	;
	
argument_list : arguments
			  {
					outlog<<"At line no: "<<lines<<" argument_list : arguments "<<endl<<endl;
					outlog<<$1->get_name()<<endl<<endl;
						
					$$ = new symbol_info($1->get_name(),"arg_list");
					$$->set_param_details($1->get_param_details());
			  }
			  |
			  {
					outlog<<"At line no: "<<lines<<" argument_list :  "<<endl<<endl;
					outlog<<""<<endl<<endl;
						
					$$ = new symbol_info("","arg_list");
					$$->set_param_details({});
			  }
			  ;
	
arguments : arguments COMMA logic_expression
		  {
				outlog<<"At line no: "<<lines<<" arguments : arguments COMMA logic_expression "<<endl<<endl;
				outlog<<$1->get_name()<<","<<$3->get_name()<<endl<<endl;
						
				$$ = new symbol_info($1->get_name()+","+$3->get_name(),"arg");
				vector<string> types = $1->get_param_details();
				types.push_back($3->get_data_type());
				$$->set_param_details(types);
		  }
	      | logic_expression
	      {
				outlog<<"At line no: "<<lines<<" arguments : logic_expression "<<endl<<endl;
				outlog<<$1->get_name()<<endl<<endl;
						
				$$ = new symbol_info($1->get_name(),"arg");
				$$->set_param_details({$1->get_data_type()});
		  }
	      ;
 

%%

int main(int argc, char *argv[])
{
	if(argc != 2) 
	{
		cout<<"Please input file name"<<endl;
		return 0;
	}
	yyin = fopen(argv[1], "r");
	outlog.open("22301651_log.txt", ios::trunc);
	outerror.open("22301651_error.txt", ios::trunc);
	
	if(yyin == NULL)
	{
		cout<<"Couldn't open file"<<endl;
		return 0;
	}

	sym_table = new symbol_table(30);
	
	outlog << "New ScopeTable with ID 1 created" << endl << endl;
	
	yyparse();
	
	outlog << endl << "Total lines: " << lines << endl;
	outlog << "Total errors: " << error_count << endl;
	outerror << "Total errors: " << error_count << endl;
	
	outlog.close();
	outerror.close();
	fclose(yyin);
	
	delete sym_table;
	
	return 0;
}
