#include "symbol_info.h"
#include <list>
#include <vector>
#include <string>
#include <fstream>
using namespace std;

class scope_table
{
private:
    int bucket__size;
    int uniqueid;
    scope_table *parent_scope;
    vector<list<symbol_info *>> table;

    int hash_function(string name)
    {
        unsigned long long hash = 5381;
        for (char c : name) {
            hash = ((hash << 5) + hash) + static_cast<unsigned char>(c);
        }
        return hash % bucket__size;
    }

public:

    scope_table(int bucket__size, int uniqueid, scope_table *parent_scope): 
        bucket__size(bucket__size), 
        uniqueid(uniqueid), 
        parent_scope(parent_scope)
    {
        table.resize(bucket__size);
    }

    scope_table *get_parent_scope() { return parent_scope; }
    int get_uniqueid() { return uniqueid; }

    symbol_info *lookup_in_scope(string name)
    {
        int index = hash_function(name);
        for (auto sym : table[index]) {
            if (sym->get_name() == name) {
                return sym;
            }
        }
        return nullptr;
    }

    bool insert_in_scope(symbol_info* symbol)
    {
        const string& symbolname = symbol->get_name();

        if (lookup_in_scope(symbolname)) return false;

        int bucketindex = hash_function(symbolname);
        table[bucketindex].push_front(symbol);
        return true;
    }

    bool delete_from_scope(symbol_info* symbol)
    {
        const string& symbolname = symbol->get_name();
        int bucketindex = hash_function(symbolname);
        list<symbol_info*>& bucket = table[bucketindex];

        auto match = find_if(bucket.begin(), bucket.end(),
            [&symbolname](symbol_info* entry) {
                return entry->get_name() == symbolname;
            });

        if (match == bucket.end()) return false;

        bucket.erase(match);
        return true;
    }

    void print_scope_table(ofstream& outlog)
    {
        outlog << "ScopeTable # " << uniqueid << endl;
        for (int bucketindex = 0; bucketindex < bucket__size; ++bucketindex) {
            const list<symbol_info*>& bucket = table[bucketindex];
            if (bucket.empty()) continue;

            outlog << bucketindex << " --> " << endl;

            for (symbol_info* symbol : bucket) {
                outlog << "< " << symbol->get_name() << " : ID >" << endl;

                const string kind = symbol->get_symbol_kind();

                if (kind == "variable") {
                    outlog << "Variable" << endl
                           << "Type: " << symbol->get_data_type() << endl;
                }
                else if (kind == "array") {
                    outlog << "Array" << endl
                           << "Type: " << symbol->get_data_type() << endl
                           << "Size: " << symbol->get_array_size() << endl;
                }
                else if (kind == "function") {
                    const vector<string>& parameters = symbol->get_param_details();

                    outlog << "Function Definition" << endl
                           << "Return Type: " << symbol->get_data_type() << endl
                           << "Number of Parameters: " << parameters.size() << endl
                           << "Parameter Details: ";

                    bool firstparameter = true;
                    for (const string& parameter : parameters) {
                        if (!firstparameter) outlog << ", ";
                        outlog << parameter;
                        firstparameter = false;
                    }
                    outlog << endl;
                }

                outlog << endl;
            }
        }
        outlog << endl;
    }

    ~scope_table()
    {
        for (auto &bucket : table) {
            for (auto sym : bucket) {
                delete sym;
            }
        }
    }
};
