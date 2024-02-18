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
        auto startTime = MonoTime.currTime();

        auto text = "
        test 1 2 3
        ";

        Farfadet ffd = new Farfadet(text);

        auto duration = MonoTime.currTime() - startTime;
        writeln("Temps écoulé: \t", duration);

        foreach (node; ffd.nodes) {
            writeln("Node: ", node.name);
            for (int i; i < 3; i++) {
                writeln("Arg ", i, ": ", node.get!int(i));
            }
        }

        //Benchmark
    }
    catch (Exception e) {
        writeln(e.msg);
        foreach (trace; e.info)
            writeln("at: ", trace);
    }
}
