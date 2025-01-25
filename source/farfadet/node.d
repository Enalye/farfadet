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
            //enforce!FarfadetException(!_isMaster, "ce nœud ne peut pas être nommé");
            enforce!FarfadetException(isValidKey(name_),
                format!"`%s` n’est pas un nom de nœud valide"(name_));
            return _name = name_;
        }
    }

    /// Crée un nœud à partir d’un document
    static Farfadet fromString(string text) {
        Farfadet ffd = new Farfadet;
        ffd._isMaster = true;
        Tokenizer tokenizer = new Tokenizer(text);

        while (!tokenizer.isEndToken()) {
            Farfadet node = new Farfadet(tokenizer);
            ffd._nodes ~= node;
        }
        return ffd;
    }

    /// Crée un nœud depuis les données bruts d’un document
    static Farfadet fromBytes(const(ubyte[]) data) {
        import std.utf : validate;

        string text = cast(string) data;
        validate(text);
        return fromString(text);
    }

    /// Crée un nœud depuis un fichier
    static Farfadet fromFile(string filePath) {
        import std.file : readText;

        string text = readText(filePath);
        return fromString(text);
    }

    /// Crée un nœud vierge
    this() {
        _isMaster = true;
    }

    /// Copie
    private this(Farfadet ffd) {
        _isMaster = ffd._isMaster;
        _name = ffd._name;
        _values = ffd._values.dup;
        foreach (Farfadet node; ffd._nodes) {
            _nodes ~= new Farfadet(node);
        }
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

    /// Récupère l’argument à la position donnée
    T get(T)(size_t index) const if (isFarfadetValueType!T) {
        enforce!FarfadetException(index < _values.length,
            format!"l’index %d dépasse les %d argument(s) disponibles"(index, _values.length));
        return _values[index].get!T();
    }

    /// Récupère les arguments de la structure à partir de la position donnée
    T get(T)(size_t index) const if (is(T == struct)) {
        T value;
        static foreach (i, field; value.tupleof) {
            value.tupleof[i] = get!(typeof(field))(index + i);
        }
        return value;
    }

    /// Nombre d’arguments du nœud
    size_t getCount() const {
        return _values.length;
    }

    void checkCount(size_t arguments) const {
        enforce!FarfadetException(arguments == _values.length,
            format!"le nœud `%s` requiert %d argument(s) mais en fournit %d"(_name,
                arguments, _values.length));
    }

    /// Ajoute un argument à la liste \
    /// Retourne le nœud lui-même pour permettre l’enchaînement
    Farfadet add(T)(T value_) if (isFarfadetValueType!T) {
        //enforce!FarfadetException(!_isMaster, "ce nœud ne peut pas avoir d’arguments");

        Value value;
        value.set!T(value_);
        _values ~= value;
        return this;
    }

    /// Ditto
    Farfadet add(T)(const T value) if (is(T == struct)) {
        static foreach (i, field; value.tupleof) {
            add!(typeof(field))(value.tupleof[i]);
        }
        return this;
    }

    /// Efface les nœuds enfants
    void clearNodes(bool makeOrphan = true) {
        if (makeOrphan) {
            foreach (node; _nodes) {
                node._makeOrphan();
            }
        }
        _nodes.length = 0;
    }

    void removeNode(Farfadet node_) {
        Farfadet[] list;
        foreach (node; _nodes) {
            if (node != node_) {
                list ~= node;
            }
        }
        _nodes = list;
    }

    private void _makeOrphan() {
        _isMaster = true;
        _name = "";
        _values.length = 0;
    }

    /// Ajoute un nœud en enfant
    Farfadet addNode(string name_) {
        Farfadet node = new Farfadet;
        node._isMaster = false;
        node.name = name_;
        _nodes ~= node;
        return node;
    }

    /// Ditto
    Farfadet addNode(Farfadet ffd) {
        Farfadet node = new Farfadet(ffd);
        _nodes ~= node;
        return node;
    }

    /// Ajoute un nœud en enfant après le nœud indiqué, s’il est valide
    Farfadet addNodeAfter(string name_, bool delegate(Farfadet) predicate) {
        int index = -1;
        foreach (size_t i, Farfadet searchNode; _nodes) {
            if (predicate(searchNode)) {
                index = cast(int) i;
                break;
            }
        }

        if (index == -1 || index + 1 == _nodes.length) {
            return addNode(name_);
        }

        index++;

        Farfadet node = new Farfadet;
        node._isMaster = false;
        node.name = name_;
        _nodes = _nodes[0 .. index] ~ node ~ _nodes[index .. $];
        return node;
    }

    /// Ditto
    Farfadet addNodeAfter(Farfadet ffd, Farfadet after) {
        int index = -1;
        foreach (size_t i, Farfadet searchNode; _nodes) {
            if (searchNode == after) {
                index = cast(int) i;
                break;
            }
        }

        if (index == -1 || index + 1 == _nodes.length) {
            return addNode(ffd);
        }

        index++;

        Farfadet node = new Farfadet(ffd);
        _nodes = _nodes[0 .. index] ~ node ~ _nodes[index .. $];
        return node;
    }

    /// Vérifie que les nœuds enfants fassent uniquement partis d’une liste
    void accept(string[] names) const {
        enforce!FarfadetException(names.length || !_nodes.length,
            "le nœud n’accepte pas de nœud enfant");

        foreach (node; _nodes) {
            bool isValid;
            foreach (name_; names) {
                if (node.name == name_) {
                    isValid = true;
                    break;
                }
            }
            enforce!FarfadetException(isValid,
                "le nœud `" ~ node.name ~ "` n’est pas valide dans `" ~ _name ~ "`, les candidats sont: " ~ _formatList(
                    names));
        }
    }

    /// Vérifie si un nœud enfant existe
    bool hasNode(string name_) const {
        foreach (node; _nodes) {
            if (node.name == name_) {
                return true;
            }
        }
        return false;
    }

    /// Retourne le premier nœud enfant avec le nom demandé
    Farfadet getNode(string name_) const {
        Farfadet result;
        foreach (node; _nodes) {
            if (node.name == name_) {
                enforce!FarfadetException(!result,
                    format!"le nœud `%s` est défini plusieurs fois dans `%s`"(name_, _name));

                result = cast(Farfadet) node;
            }
        }
        enforce!FarfadetException(result, format!"le nœud `%s` est absent de `%s`"(name_, _name));
        return result;
    }

    /// Ditto
    Farfadet getNode(string name_, size_t expectedArguments) const {
        Farfadet result = getNode(name_);
        result.checkCount(expectedArguments);
        return result;
    }

    /// Retourne tous les nœuds enfants ayant le nom demandé
    Farfadet[] getNodes(string name_) const {
        Farfadet[] list;
        foreach (node; _nodes) {
            if (node.name == name_) {
                list ~= cast(Farfadet) node;
            }
        }
        return list;
    }

    /// Ditto
    Farfadet[] getNodes(string name_, size_t expectedArguments) const {
        Farfadet[] list = getNodes(name_);
        foreach (node; list) {
            node.checkCount(expectedArguments);
        }
        return list;
    }

    /// Retourne tous les nœuds enfants
    Farfadet[] getNodes() const {
        return cast(Farfadet[]) _nodes;
    }

    void setNodes(Farfadet[] nodes) {
        _nodes = nodes;
    }

    /// Retourne le nombre de nœuds enfants ayant le nom demandé
    size_t getNodeCount(string name_) const {
        return getNodes(name_).length;
    }

    /// Lance une erreur
    void fail(string msg, string file = __FILE__, size_t line = __LINE__) const {
        throw new FarfadetException(msg, file, line);
    }

    /// Génère un fichier et l’enregistre
    void save(string filePath, size_t spacing = 4) const {
        import std.file : write;

        write(filePath, generate(spacing));
    }

    /// Génère un fichier
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

private string _formatList(string[] names) {
    string result;
    bool isInit = true;
    foreach (name; names) {
        if (isInit) {
            isInit = false;
        }
        else {
            result ~= ", ";
        }
        result ~= "`" ~ name ~ "`";
    }
    return result;
}
