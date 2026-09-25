#include<bits/stdc++.h>
using namespace std;

class symbol_info
{
private:
    string name;
    string type; // original type from lex
    // New fields for symbol table
    string symbol_kind; // "variable", "array", "function"
    string data_type;   // "int", "float", "void"
    int array_size;     // for arrays, default 0
    vector<string> param_details; // for functions, e.g., "int a"

public:
    symbol_info(string name, string type)
    {
        this->name = name;
        this->type = type;
        this->symbol_kind = "";
        this->data_type = "";
        this->array_size = 0;
    }

    string get_name() { return name; }
    string get_type() { return type; }
    void set_name(string name) { this->name = name; }
    void set_type(string type) { this->type = type; }

    // New getters and setters
    string get_symbol_kind() const
    {
        return this->symbol_kind;
    }


    void set_symbol_kind(const string& kind)
    {
        this->symbol_kind = kind;
    }

    string get_data_type() const
    {
        return this->data_type;
    }

    void set_data_type(const string& datatype)
    {
        this->data_type = datatype;
    }

    int get_array_size() const
    {
        return this->array_size;
    }

    void set_array_size(int size)
    {
        this->array_size = size;
    }

    const vector<string>& get_param_details() const
    {
        return this->param_details;
    }

    void set_param_details(const vector<string>& parameters)
    {
        this->param_details = parameters;
    }



    ~symbol_info()
    {
        // nothing to free
    }
};
