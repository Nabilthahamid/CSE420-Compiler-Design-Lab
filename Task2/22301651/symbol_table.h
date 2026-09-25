#include "scope_table.h"

class symbol_table
{
private:
    scope_table *current_scope;
    int bucketcount;
    int nextscopeid;

public:
    symbol_table(int buckets): 
    current_scope(nullptr), 
    bucketcount(buckets), 
    nextscopeid(1)
    {
        current_scope = new scope_table(bucketcount, nextscopeid, nullptr);
        ++nextscopeid;
    }

    ~symbol_table()
    {
        while (current_scope) {
            scope_table* scopetodelete = current_scope;
            current_scope = current_scope->get_parent_scope();
            delete scopetodelete;
        }
    }

    void enter_scope(ofstream& outlog)
    {
        current_scope = new scope_table(bucketcount, nextscopeid, current_scope);
        ++nextscopeid;

        outlog << "New ScopeTable with ID "
               << current_scope->get_uniqueid()
               << " created" << endl << endl;
    }

    void exit_scope(ofstream& outlog)
    {
        if (!current_scope) return;

        scope_table* scopetodelete = current_scope;
        current_scope = scopetodelete->get_parent_scope();

        outlog << "Scopetable with ID "
               << scopetodelete->get_uniqueid()
               << " removed" << endl << endl;

        delete scopetodelete;
    }

    bool insert(symbol_info* symbol, ofstream& outlog)
    {
        if (!current_scope) return false;

        bool inserted = current_scope->insert_in_scope(symbol);
        if (inserted) return true;

        outlog << "Error: " << symbol->get_name()
            << " already declared in current scope" << endl;
        return false;
    }

    bool remove(symbol_info* symbol)
    {
        return current_scope && current_scope->delete_from_scope(symbol);
    }

    symbol_info* lookup(string name)
    {
        for (scope_table* scope = current_scope;
            scope != nullptr;
            scope = scope->get_parent_scope()) {
            symbol_info* result = scope->lookup_in_scope(name);
            if (result) return result;
        }

        return nullptr;
    }

    void print_current_scope(ofstream& outlog)
    {
        if (current_scope) current_scope->print_scope_table(outlog);
    }

    void print_all_scopes(ofstream& outlog)
    {
        outlog << "################################" << endl << endl;

        scope_table* scope = current_scope;
        while (scope != nullptr) {
            scope->print_scope_table(outlog);
            scope = scope->get_parent_scope();
        }

        outlog << "################################" << endl << endl;
    }
};
