/** 
 * Droits d’auteur: Enalye
 * Licence: Zlib
 * Auteur: Enalye
 */
import std.stdio : writeln, write;
import std.string;
import std.datetime;
import std.conv : to;

import farfadet;

void main() {
    version (Windows) {
        import core.sys.windows.windows : SetConsoleOutputCP;

        SetConsoleOutputCP(65_001);
    }
    try {
        auto text = "
        test1 1 2 3
        test2 [1 -2 3] {
            test \"bonjour\" {
                bool true false
                int +1.3 -46
            }
        }
        ";

        Farfadet ffd = new Farfadet(text);

        writeln("Généré: `", ffd.generate(), "`");

        foreach (node; ffd.nodes) {
            switch (node.name) {
            case "test1":
                for (int i; i < 3; i++) {
                    writeln("Arg ", i, ": ", node.get!(int)(i));
                }
                break;
            case "test2":
                writeln(node.get!(int[])(0));
                break;
            default:
                break;
            }
        }
    }
    catch (FarfadetSyntaxException e) {
        writeln("Farfadet: ", e.msg, " at (", e.tokenLine, ":", e.tokenColumn, ")");
    }
    catch (FarfadetException e) {
        writeln("Farfadet: ", e.msg);
    }
    catch (Exception e) {
        writeln(e.msg);
        foreach (trace; e.info)
            writeln("at: ", trace);
    }
}
