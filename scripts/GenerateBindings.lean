import Lean
import Bindings
import LeanGodot

open Lean
open IO

-- Define the available commands and options using `OptionParser`
def GenGodotInits : String := #GenGodotInits
def GenGodotDeclarations : String := #GenGodotDeclarations
def printHelp : IO Unit :=
  println "Usage: godotgen <command>\n\nAvailable commands:\n  Init           Generate initialization code\n  Declarations   Generate binding declarations\n  --help, -h     Show this message"

-- CLI Command enumeration
inductive CLICommand
| init
| declarations
| help


-- Define the CLI arguments parser
def parseArgs : CLICommand → IO Unit
| .init         => println GenGodotInits
| .declarations => println GenGodotDeclarations
| .help         => printHelp



-- Parse the argument into the appropriate command type
def Command.ofString? (s : String) : Option CLICommand :=
  match s with
  | "Init"         => some .init
  | "Declarations" => some .declarations
  | "--help" | "-h"=> some .help
  | _              => none

-- Main CLI entry point
def main (args : List String) : IO Unit := do
  match args with
  | [] =>
    eprintln "Error: no command provided.\n"
    printHelp
  | [arg] =>
    match Command.ofString? arg with
    | some cmd => parseArgs cmd
    | none     =>
      eprintln s!"Error: unknown command '{arg}'.\n"
      printHelp
  | _ =>
    eprintln "Error: too many arguments.\n"
    printHelp
