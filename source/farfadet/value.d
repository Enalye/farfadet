/** 
 * Droits d’auteur: Enalye
 * Licence: Zlib
 * Auteur: Enalye
 */
module farfadet.value;

import std.conv : to;
import std.exception : enforce;
import std.traits;

import farfadet.error;

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
        static if (isSomeString!T) {
            enforce!FarfadetException(_type == Type.string_, "the value is not a string");
            return to!T(_string);
        }
        else static if (is(T == U[], U)) {
            T result;
            foreach (value; _array) {
                result ~= value.get!U();
            }
            return result;
        }
        else static if (isSomeChar!T) {
            enforce!FarfadetException(_type == Type.char_, "the value is not a character");
            return to!T(_char);
        }
        else static if (is(T == bool)) {
            enforce!FarfadetException(_type == Type.bool_, "the value is not boolean");
            return _bool;
        }
        else static if (__traits(isIntegral, T)) {
            static if (__traits(isUnsigned, T)) {
                switch (_type) with (Type) {
                case uint_:
                    static if (T.sizeof < ulong.sizeof) {
                        enforce!FarfadetException(_uint < T.max, "the value is too big");
                    }
                    return cast(T) _uint;
                case int_:
                    enforce!FarfadetException(_int >= 0, "the value is negative");
                    static if (T.sizeof < long.sizeof) {
                        enforce!FarfadetException(_int < T.max, "the value is too big");
                    }
                    return cast(T) _int;
                default:
                    throw new FarfadetException("the value is not an integral number");
                }
            }
            else static if (isSigned!T) {
                switch (_type) with (Type) {
                case uint_:
                    static if (T.sizeof < ulong.sizeof) {
                        enforce!FarfadetException(_uint < T.max, "the value is too big");
                    }
                    static if (T.sizeof == ulong.sizeof) {
                        enforce!FarfadetException(_uint & (1uL << 63), "the value is too big");
                    }
                    return cast(T) _uint;
                case int_:
                    static if (T.sizeof < long.sizeof) {
                        enforce!FarfadetException(_int < T.max, "the value is too big");
                    }
                    return cast(T) _int;
                default:
                    throw new FarfadetException("the value is not an integral number");
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
                throw new FarfadetException("the value is not a floating point number");
            }
        }
        else {
            static assert(false, "unsupported type `" ~ T.stringof ~ "`");
        }
    }

    /// Modifie la valeur au bon format
    void set(T)(T value) {
        static if (isSomeString!T) {
            _string = to!string(value);
            _type = Type.string_;
        }
        else static if (is(T == U[], U)) {
            _array.length = 0;
            foreach (ref element; value) {
                Value value;
                value.set!U(element);
                _array ~= value;
            }
            _type = Type.array_;
        }
        else static if (isSomeChar!T) {
            _char = to!dchar(value);
            _type = Type.char_;
        }
        else static if (is(T == bool)) {
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
            static assert(false, "unsupported type `" ~ T.stringof ~ "`");
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
