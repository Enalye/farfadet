/** 
 * Droits d’auteur: Enalye
 * Licence: Zlib
 * Auteur: Enalye
 */
module farfadet.node;

import std.conv : to;
import std.exception : enforce;
import std.format : format;

import farfadet.error;
import farfadet.token;
import farfadet.tokenizer;
import farfadet.value;

final class Farfadet {
    private {
        bool _isMaster;
        string _name;
        Value[] _values;
        Farfadet[] _nodes;
    }

    @property {
        /// Le nom du nœud
        string name() const {
            return _name;
        }
        /// Ditto
        string name(string name_) {
            enforce!FarfadetException(!_isMaster, "ce nœud ne peut pas être nommé");
            enforce!FarfadetException(isValidKey(name_),
                format!"`%s` n’est pas un nom de nœud valide"(name_));
            return _name = name_;
        }

        /// Les nœuds enfants
        const(Farfadet[]) nodes() const {
            return _nodes;
        }
    }

    /// Crée un nœud à partir d’un document
    this(string text) {
        _isMaster = true;
        Tokenizer tokenizer = new Tokenizer(text);

        while (!tokenizer.isEndToken()) {
            Farfadet node = new Farfadet(tokenizer);
            _nodes ~= node;
        }
    }

    /// Crée un nœud depuis les données bruts d’un document
    this(const(ubyte[]) data) {
        import std.utf : validate;

        string text = cast(string) data;
        validate(text);
        this(text);
    }

    /// Crée un nœud vierge
    this() {
        _isMaster = true;
    }

    private this(Tokenizer tokenizer) {
        _isMaster = false;
        Token token = tokenizer.getToken();
        tokenizer.check(token.type == Token.Type.key,
            format!"clé manquante, `%s` trouvé à la place"(token.toString()));

        _name = token.strValue;
        tokenizer.advanceToken();

        while (!tokenizer.isEndToken()) {
            token = tokenizer.getToken();
            switch (token.type) with (Token.Type) {
            case openBlock:
                _parseBlock(tokenizer);
                return;
            case key:
            case closeBlock:
                return;
            default:
                _values ~= _parseParameter(tokenizer);
                break;
            }
        }
    }

    private void _parseBlock(Tokenizer tokenizer) {
        tokenizer.advanceToken();
        for (;;) {
            tokenizer.check(!tokenizer.isEndToken(), "symbole `}` manquant après un `{`");
            Token token = tokenizer.getToken();
            if (token.type == Token.Type.closeBlock) {
                tokenizer.advanceToken();
                return;
            }

            Farfadet node = new Farfadet(tokenizer);
            _nodes ~= node;
        }
    }

    private Value _parseParameter(Tokenizer tokenizer) {
        Token token = tokenizer.getToken();
        final switch (token.type) with (Token.Type) {
        case key:
            tokenizer.check(false, "clé inattendu à la place d’un argument");
            return Value(0);
        case int_:
            tokenizer.advanceToken();
            return Value(token.intValue);
        case uint_:
            tokenizer.advanceToken();
            return Value(token.uintValue);
        case char_:
            tokenizer.advanceToken();
            return Value(token.charValue);
        case float_:
            tokenizer.advanceToken();
            return Value(token.floatValue);
        case string_:
            tokenizer.advanceToken();
            return Value(token.strValue);
        case bool_:
            tokenizer.advanceToken();
            return Value(token.boolValue);
        case openBlock:
            tokenizer.check(false, "symbole `{` inattendu au lieu d’un argument");
            return Value(0);
        case closeBlock:
            tokenizer.check(false, "symbole `}` inattendu au lieu d’un argument");
            return Value(0);
        case openArray:
            Value[] array;
            tokenizer.advanceToken();
            for (;;) {
                token = tokenizer.getToken();
                if (token.type == Token.Type.closeArray) {
                    tokenizer.advanceToken();
                    break;
                }
                array ~= _parseParameter(tokenizer);
            }
            return Value(array);
        case closeArray:
            tokenizer.check(false, "symbole `]` inattendu au lieu d’un argument");
            return Value(0);
        }
    }

    /// Retire tous les arguments du nœud
    void clear() {
        _values.length = 0;
    }

    /// Récupère l’argument à la position donné
    T get(T)(size_t index) const {
        enforce!FarfadetException(index < _values.length,
            format!"l’index %d dépasse les %d argument(s) disponibles"(index, _values.length));
        return _values[index].get!T();
    }

    /// Ajoute un argument à la liste
    void add(T)(T value) {
        enforce!FarfadetException(!_isMaster, "ce nœud ne peut pas avoir d’arguments");

        Value value;
        value.set!T(value);
        _values ~= value;
    }

    void clearNodes() {
        foreach (node; _nodes) {
            node._makeOrphan();
        }
        _nodes.length = 0;
    }

    private void _makeOrphan() {
        _isMaster = true;
        _name = "";
        _values.length = 0;
    }

    Farfadet addNode(string name_) {
        Farfadet node = new Farfadet;
        node._isMaster = false;
        node.name = name_;
        return node;
    }

    string generate(size_t spacing = 4) const {
        return _generate(0, spacing);
    }

    private string _generate(size_t indent, size_t spacing) const {
        string result;

        if (_isMaster) {
            foreach (node; _nodes) {
                result ~= node._generate(indent, spacing);
            }
        }
        else {
            for (int i; i < indent; i++) {
                result ~= " ";
            }

            result ~= _name;

            foreach (value; _values) {
                result ~= " " ~ value.toString();
            }

            if (_nodes.length)
                result ~= " {\n";
            foreach (node; _nodes) {
                result ~= node._generate(indent + spacing, spacing);
            }
            if (_nodes.length) {
                for (int i; i < indent; i++) {
                    result ~= " ";
                }
                result ~= "}";
            }

            result ~= "\n";
        }

        return result;
    }
}
