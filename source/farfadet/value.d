/** 
 * Droits d’auteur: Enalye
 * Licence: Zlib
 * Auteur: Enalye
 */
module farfadet.value;

import std.conv : to, ConvException;
import std.exception : enforce;
import std.traits;

import farfadet.error;

public template isFarfadetCompatible(T) {
    enum isFarfadetCompatible = is(T == struct) || isFarfadetValueType!T;
}

package template isFarfadetValueType(T) {
    enum isFarfadetValueType = isSomeString!T || isSomeChar!T || is(Unqual!T == U[],
            U) || is(Unqual!T == bool) || __traits(isIntegral, T) || __traits(isFloating, T);
}

package struct Value {
    enum Type {
        uint_,
        int_,
        char_,
        float_,
        bool_,
        string_,
        array_
    }

    private {
        Type _type;

        union {
            ulong _uint;
            long _int;
            dchar _char;
            double _float;
            bool _bool;
            string _string;
            Value[] _array;
        }
    }

    this(ulong value) {
        _type = Type.uint_;
        _uint = value;
    }

    this(long value) {
        _type = Type.int_;
        _int = value;
    }

    this(dchar value) {
        _type = Type.char_;
        _char = value;
    }

    this(double value) {
        _type = Type.float_;
        _float = value;
    }

    this(bool value) {
        _type = Type.bool_;
        _bool = value;
    }

    this(string value) {
        _type = Type.string_;
        _string = value;
    }

    this(Value[] values) {
        _type = Type.array_;
        _array = values;
    }

    /// Récupère la valeur au bon format
    T get(T)() const {
        static if (is(Unqual!T == enum)) {
            enforce!FarfadetException(_type == Type.string_, "la valeur n’est pas une énumération");
            try {
                return to!T(_string);
            }
            catch (ConvException e) {
                throw new FarfadetException("l’énumération n’est pas un champ valide");
            }
        }
        else static if (isSomeString!T) {
            enforce!FarfadetException(_type == Type.string_, "la valeur n’est pas un string");
            return to!T(_string);
        }
        else static if (is(Unqual!T == U[], U)) {
            T result;
            foreach (value; _array) {
                result ~= value.get!U();
            }
            return result;
        }
        else static if (isSomeChar!T) {
            enforce!FarfadetException(_type == Type.char_, "la valeur n’est pas un caractère");
            return to!T(_char);
        }
        else static if (is(Unqual!T == bool)) {
            enforce!FarfadetException(_type == Type.bool_, "la valeur n’est pas booléenne");
            return _bool;
        }
        else static if (__traits(isIntegral, T)) {
            static if (__traits(isUnsigned, T)) {
                switch (_type) with (Type) {
                case uint_:
                    static if (T.sizeof < ulong.sizeof) {
                        enforce!FarfadetException(_uint < T.max, "la valeur est trop grande");
                    }
                    return cast(T) _uint;
                case int_:
                    enforce!FarfadetException(_int >= 0, "la valeur est négative");
                    static if (T.sizeof < long.sizeof) {
                        enforce!FarfadetException(_int < T.max, "la valeur est trop grande");
                    }
                    return cast(T) _int;
                default:
                    throw new FarfadetException("la valeur n’est pas un nombre intégral");
                }
            }
            else static if (isSigned!T) {
                switch (_type) with (Type) {
                case uint_:
                    static if (T.sizeof < ulong.sizeof) {
                        enforce!FarfadetException(_uint < T.max, "la valeur est trop grande");
                    }
                    static if (T.sizeof == ulong.sizeof) {
                        enforce!FarfadetException(_uint & (1uL << 63), "la valeur est trop grande");
                    }
                    return cast(T) _uint;
                case int_:
                    static if (T.sizeof < long.sizeof) {
                        enforce!FarfadetException(_int < T.max, "la valeur est trop grande");
                    }
                    return cast(T) _int;
                default:
                    throw new FarfadetException("la valeur n’est pas un nombre intégral");
                }
            }
        }
        else static if (__traits(isFloating, T)) {
            switch (_type) with (Type) {
            case uint_:
                return cast(T) _uint;
            case int_:
                return cast(T) _int;
            case float_:
                return cast(T) _float;
            default:
                throw new FarfadetException("la valeur n’est pas un nombre à virgule flottante");
            }
        }
        else {
            static assert(false, "type `" ~ T.stringof ~ "` non-supporté");
        }
    }

    /// Modifie la valeur au bon format
    void set(T)(const T value) {
        static if (is(Unqual!T == enum)) {
            _string = to!string(value);
            _type = Type.string_;
        }
        else static if (isSomeString!T) {
            _string = to!string(value);
            _type = Type.string_;
        }
        else static if (is(Unqual!T == U[], U)) {
            _array.length = 0;
            foreach (ref element; value) {
                Value subValue;
                subValue.set!U(element);
                _array ~= subValue;
            }
            _type = Type.array_;
        }
        else static if (isSomeChar!T) {
            _char = to!dchar(value);
            _type = Type.char_;
        }
        else static if (is(Unqual!T == bool)) {
            _bool = value;
            _type = Type.bool_;
        }
        else static if (__traits(isIntegral, T)) {
            static if (__traits(isUnsigned, T)) {
                _uint = value;
                _type = Type.uint_;
            }
            else static if (isSigned!T) {
                _int = value;
                _type = Type.int_;
            }
        }
        else static if (__traits(isFloating, T)) {
            _float = value;
            _type = Type.float_;
        }
        else {
            static assert(false, "type `" ~ T.stringof ~ "` non-supporté");
        }
    }

    string toString() const {
        final switch (_type) with (Type) {
        case uint_:
            return to!string(_uint);
        case int_:
            return to!string(_int);
        case char_:
            return "'" ~ to!string(_char) ~ "'";
        case float_:
            return to!string(_float);
        case bool_:
            return _bool ? "true" : "false";
        case string_:
            return "\"" ~ _string ~ "\"";
        case array_:
            string result = "[";
            bool firstValue = true;
            foreach (ref value; _array) {
                if (firstValue) {
                    firstValue = false;
                }
                else {
                    result ~= " ";
                }
                result ~= value.toString();
            }
            result ~= "]";
            return result;
        }
    }
}
