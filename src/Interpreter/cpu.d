module cpu;

import registers;
import stack;

import std.stdio;
import std.string;
import std.file;
import std.path : extension;
import std.c.stdlib;
import std.array;
import std.conv;

enum : int
{
	/* OPCODES */
	NOP = 0x0,
	SWP = 0x1,
	ADD = 0x2,
	SUB = 0x3,
	MUL = 0x4,
	DIV = 0x5,
	LSHIFT = 0x6,
	RSHIFT = 0x7,
	NOT = 0x8,
	AND = 0x9,
	OR = 0xA,
	XOR = 0xB,
	CMP = 0xC,
	PUSH = 0xD, 
	POP = 0xE, 
	REGSET = 0xF, 
	REGSHOW = 0x10, 
	MEMSHOW = 0x11, 
	DEBUG = 0x12, 
	INTERRUPT = 0x13,
	FLAGSHOW = 0x14, 
	IFE = 0x15, 			/* If equal */
	IFNE = 0x16, 			/* If not equal */
	INC = 0x17,
	DEC = 0x18,   
	JMP = 0x19,
	DEF = 0x20,
	LBL = 0x21,			// Label 
	CALL = 0x22,
	RET = 0x23,
	EOC = 0x24,			//End of code

	/* Symbols */
	NL = 0xC0,				//New line
	EOB = 0xC1, 			//End of block
	COM = 0xC2, 			//Comment
	STR = 0xC3, 			//String identifier, i.e. ' " '

	/* Registers */
	REG0 = 0xF0,
	REG1 = 0xF1,
	REG2 = 0xF2, 
	REG3 = 0xF3, 
	REG4 = 0xF4, 
	REG5 = 0xF5, 
	REG6 = 0xF6, 
	REG7 = 0xF7, 
	REG8 = 0xF8, 
	REG9 = 0xF9
}

struct token
{
	int type; /* Type 0 = OPCODE, type 1 = Integer, type 2 = string */
	union
	{
		int nData;
		string cData;
		int opcode;
	}
}

int[string] intVariable;
string[string] strVariable;
int[string] labels;
bool debug_bit = false; 
int returnNum;
int flagA = 0;
int flagB = 0;
token mem[];

void dPrint(string message)
{
	if(debug_bit)
	{
		writeln("DEBUG: " ~ message);
	}
	return;
}

bool isInterrupt()
{
	dPrint("In isInterrupt()");
	if(reg[0].nData == 1)
	{
		dPrint("isInterrupt() returning true for exit interrupt");
		return true;
	}
	else if(reg[0].nData == 2 && reg[1].cData != null && reg[2].cData != null || reg[2].nData != 0)
	{
		dPrint("isInterrupt() returning true for write interrupt");
		return true;
	}
	else if(reg[0].nData == 3 && reg[1].cData != null && reg[2].nData != 0)
	{
		dPrint("isInterrupt() returning true for read interrupt");
		return true;
	}
	dPrint("isInterrupt() returning false");
	return false;
}

void executeInt()
{
	dPrint("In executeInt()");
	if(reg[0].nData == 1)
	{
		dPrint("Executing exit interrupt!");
		exit(reg[1].nData);
	}
	if(reg[0].nData == 2 && reg[1].cData != null && (reg[2].cData != null || reg[2].nData != 0))
	{
		dPrint("Executing write interrupt!");
		if(reg[1].cData == "stdout")
		{
			dPrint("Writing to stdout");

			if(reg[2].nData != 0)
			{
				if(reg[2].nData == NL)
				{
					writeln("");
					return;
				}
				int regNum = reg[2].nData;
				writef("%s", getData(regNum));
			}
			else
			{
				writef("%s", getData(REG2));
			}
		}
		else
		{
			dPrint("Writing to file");
			string fileName = reg[1].cData;
			string text = reg[2].cData;
			std.file.write(fileName, text);
		}
		return; 
	}

	if(reg[0].nData == 3 && reg[1].cData != null && reg[2].nData != 0)
	{
		dPrint("Executing read interrupt!");
		if(reg[1].cData == "stdin")
		{
			dPrint("Reading from stdin");
			string buf;
			if((buf = stdin.readln()) !is null) /* If it's not null (!= gave a conflicting types error) */ 
			{
				setReg(REG4, chop(buf));
			}
			else
			{
				writeln("Error: Something went wrong when reading in the data.");
			}
		}
		else
		{
			dPrint("Reading from file");
			string fileName = reg[1].cData;
			auto text = read(fileName, reg[2].nData);
			setReg(4, cast(string)text);
		}
		return;
	}
	dPrint("executeInt() has ran, but nothing was executed.");
}

void memShow()
{
	dPrint("In memShow()");
	for(int i = 0; i < mem.length; i++)
	{
		if(mem[i].type == 0)
		{
			writefln("[%d]: %d", i, mem[i].opcode);
		}
		else if(mem[i].type == 1)
		{
			writefln("[%d]: %d", i, mem[i].nData);
		}
		else
		{
			writefln("[%d]: %s", i, mem[i].cData);
		}
	}
}

int toHexadecimal(string data)
{
	return to!int(strtoul(toStringz(data), null, 16));
}

void setRegOnOp(ref int i, int delegate(int,int) operation)
{
	int arg = mem[++i].nData;
	int regNum = mem[++i].opcode;
	int reg = toInt(getData(regNum));

	setReg(regNum, operation(reg, arg));
}

int getNextInt(ref int i)
{
	i++;
	if(isRegister(mem[i].opcode))
	{
		return toInt(getData(mem[i].opcode));
	}
	return mem[i].nData;
}

void decode(string characters)
{
	dPrint("In decode()");
	auto tokens = characters.split();
	int i;
	mem.length = tokens.length + 2; /* Dynamically allocating the memory, and adding enough extra for the last token
										found, and the EOC token. */
	while(i < tokens.length && tokens[i].ptr != null)
	{
		string currentToken = tokens[i];

		int * intVarTest = currentToken in intVariable; /* Will be null if the key doesn't exist */
		string * strVarTest = currentToken in strVariable;
		int * lblTest = currentToken in labels;
		if(intVarTest) /* If the key exists */
		{
			mem[i].type = 1;
			mem[i].nData = intVariable[currentToken]; /* Replace it in memory with it's value */
		} 
		else if(strVarTest)
		{
			mem[i].type = 2;
			mem[i].cData = strVariable[currentToken];
		}
		else if(lblTest) 
		{
			mem[i].type = 1;
			mem[i].nData = labels[currentToken];
		}
		else if(indexOf(currentToken, "0x") != -1)
		{
			if(currentToken == "0x20")		/* Variables */
			{
				dPrint("DEF OPCODE found!");
				mem[i].type = 0;
				i++; 	

				string varName = tokens[i];
				i++;
				if(isNumeric(tokens[i]))
				{
					int varVal = toInt(tokens[i]);
					intVariable[varName] =  varVal;
				}
				else
				{
					if(tokens[i] == "0xC3")
					{
						i++;
						string varVal;
						while(tokens[i] != "0xC3")
						{
							varVal ~= tokens[i] ~ " ";
							i++;
						}
						strVariable[varName] = varVal;
					}
				}
			}
			else if(currentToken == "0x21")		/* Labels */
			{
				dPrint("LBL OPCODE found!");
				mem[i].type = 0;
				mem[i].opcode = toHexadecimal(currentToken);
				i++;

				string lblName = tokens[i];
				labels[lblName] = i;	
			}
			else
			{
				mem[i].type = 0;
				mem[i].opcode = toHexadecimal(currentToken);
			}
		}
		else if(isNumeric(currentToken))
		{
			mem[i].type = 1;
			mem[i].nData = toInt(currentToken);
		}
		else
		{
			mem[i].type = 2;
			mem[i].cData = currentToken;
		}
		i++;
	}
	i++;
	mem[i].opcode = EOC;
}

void execute()
{
	dPrint("In execute() function");
	for(int i = 0; i < mem.length; i++)
	{
		switch(mem[i].opcode)
		{
			case LBL:
				dPrint("LBL OPCODE found!");
				while(mem[i].opcode != EOB)
				{
					i++;
				}
				break;
			case RET:
				dPrint("RET OPCODE found!");
				i = returnNum;
				break;
			case CALL:
				dPrint("CALL OPCODE found!");
				i++;		
				returnNum = i;	
				int jmp = mem[i].nData;
				i = jmp;
				break;
			case COM:
				dPrint("COM OPCODE found!");
				i++;
				while(mem[i].opcode != COM)
				{
					i++;
				}
				break;
			case INC:
				dPrint("INC OPCODE found");
				i++;
				int regNum = mem[i].opcode;
				int data = toInt(getData(regNum));
				data++;
				setReg(regNum, data);
				break;
			case DEC:
				dPrint("DEC OPCODE found");
				i++;
				int regNum = mem[i].opcode;
				int data = toInt(getData(regNum));
				data--;
				setReg(regNum, data);
				break;
			case NOP:
				dPrint("NOP OPCODE found, doing nothing.");
				break;
			case JMP:
				dPrint("JMP OPCODE found");
				i++;
				int jmp = mem[i].nData;
				i = jmp;
				break;
			case IFE:
				dPrint("IFE OPCODE found");
				if(flagA != 1)
				{
					while(mem[i].opcode != EOB)
					{
						i++;
					}
				}
				flagA = 0;
				break;
			case IFNE:
				dPrint("IFNE OPCODE found");
				if(flagA != 0)
				{
					while(mem[i].opcode != EOB)
					{
						i++;
					}
				}
				flagA = 0;
				break;
			case XOR:
				dPrint("XOR OPCODE found");
				setRegOnOp(i, (x,y) => x ^ y);
				break;
			case OR:
				dPrint("OR OPCODE found");
				setRegOnOp(i, (x,y) => x | y);
				break;
			case AND:
				dPrint("AND OPCODE found");
				setRegOnOp(i, (x,y) => x & y);
				break;
			case RSHIFT:
				dPrint("RSHIFT OPCODE found");
				setRegOnOp(i, (x,y) => x >> y);
				break;
			case LSHIFT:
				dPrint("LSHIFT OPCODE found");
				setRegOnOp(i, (x,y) => x << y);
				break;
			case FLAGSHOW:
				dPrint("FLAGSHOW OPCODE found");
				writefln("Flag A: %d", flagA);
				writefln("Flag B: %d", flagB);
				break;
			case CMP:
				dPrint("CMP OPCODE found");
				i++;

				/* Because all of these get assigned to null or 0 at runtime, if we don't assign them to different values, 
				then they'll still evaluate to true in the comparison below. (If we're testing numbers, then num and num2 
				will differ, but text and text2 will still be evaluated to null, and thus be equal and fuck everything
				up) */
				int num = 0;
				int num2 = 1;
				string text = "text";
				string text2 = "text2";
				
				/* Finding out the first peice of data to compare, and assigning it to the variable */
				if(mem[i].type == 0) /* Must be register or string*/
				{
					if(isRegister(mem[i].opcode))
					{
						string data = getData(mem[i].opcode);	
						if(isNumeric(data))
						{
							num = toInt(data);
						}
						else
						{
							text = data;
						}
					}
					/* String? */
					else if(mem[i].opcode == STR)
					{
						i++;

						/* Clear out the original random value we had */
						text = "";

						while(mem[i].opcode != STR)
						{
							text ~= mem[i].cData ~ " ";
							i++;
						}
					}
				}
				else if(mem[i].type == 1)
				{
					num = mem[i].nData;
				}
				i++;

				/* Same thing as above, but for the second peice of data */
				if(mem[i].type == 0) /* Must be register or string */
				{
					int regNum = toReg(mem[i].opcode);
					if(isRegister(mem[i].opcode))
					{
						string data = getData(regNum);	
						if(isNumeric(data))
						{
							num2 = toInt(data);
						}
						else
						{
							text2 = data;
						}
					}
					/* String? */
					else if(mem[i].opcode == STR)
					{
						i++;

						/* Clear out the original random value we had */
						text2 = "";
						while(mem[i].opcode != STR)
						{
							text2 ~= mem[i].cData ~ " ";
							i++;
						}
					}
				}
				else if(mem[i].type == 1)
				{
					num2 = mem[i].nData;
				}

				/* The actual comparison */
				if(num == num2 || text == text2)
				{
					flagA = 1;
					break;
				}
				flagA = 0;	
				break;

			case INTERRUPT:
				dPrint("Interrupt OPCODE found");
				if(isInterrupt())
				{
					dPrint("Found interrupt");
					executeInt();
				}
				else
				{
					writeln("Error: Interrupt signal recieved, but no interrupt was found!");
					exit(1);
				}
				break;
			case MEMSHOW:
				dPrint("MEMSHOW OPCODE found");
				memShow();
				break;
			case DEBUG:
				if(!debug_bit)
				{
				    debug_bit = true;
				    dPrint("Debug mode is now on, prepare to be overloaded.");
				}
				else
				{
				    dPrint("Setting DEBUG to 0, goodbye cruel world!");
				    debug_bit = false;
				}
				writeln("Setting debug bit to: ", debug_bit);
				break;
			case REGSET:
				dPrint("REGSET OPCODE found");
				i++;
				int regA = mem[i].opcode;
				string data;
				i++;
				if(mem[i].opcode == STR && mem[++i].type == 2)
				{
					while(mem[i].opcode != STR)
					{
						data ~= mem[i].cData ~ " ";
						i++;
					}
					if(isRegister(regA))
					{
						setReg(regA, chop(data)); /* Remove the '\n\r' and space */
					}
				}
				else
				{
					int info = mem[i].nData;
					if(isRegister(regA))
					{
						setReg(regA, info);
					}
				}
				break;
			case SWP:
				dPrint("MOV OPCODE found");
				i++;
				if(mem[i].opcode)
				{
					int regNumA = mem[i].opcode;
					if(mem[i].opcode)
					{
						i++;
						int regNumB = mem[i].opcode;
						string data = getData(regNumB);
						setReg(regNumA, data);
					}
				}
				break;
            		case REGSHOW:
				dPrint("REGSHOW OPCODE found");
				displayReg();
				break;
			case ADD:
				dPrint("ADD OPCODE found");
				setReg(REG0, getNextInt(i) + getNextInt(i));
				break;
			case SUB:
				dPrint("SUB OPCODE found");
				setReg(REG0, getNextInt(i) - getNextInt(i));
				break;
			case MUL:
				dPrint("MUL OPCODE found");
				setReg(REG0, getNextInt(i) * getNextInt(i));
				break;
			case DIV:
				dPrint("DIV OPCODE found");
				setReg(REG0, getNextInt(i) / getNextInt(i));
				break;
			case PUSH:
				dPrint("PUSH OPCODE found");
				i++;
				string pushString;
				if(mem[i].opcode == STR)
				{
					i++;
					while(mem[i].opcode != STR)
					{
						pushString ~= mem[i].cData ~ " ";
						i++;
					}
				}
				else
				{
					pushString = toString(mem[i].nData);
				}
				push(pushString);
				break;
			case POP:
				dPrint("POP OPCODE found");
				i++;
				int regNum = mem[i].opcode;
				if(isRegister(regNum))
				{
					setReg(regNum, pop());
				}
				else if(!isRegister(regNum))
				{
					writefln("Error: %d is not a valid register!", regNum);
					exit(1);
				}
				else
				{
					writefln("Error: You must specify a register to hold the value!");
					exit(1);
				}
				break;
			case EOC:
				dPrint("EOC OPCODE found");
				dPrint("So long and thanks for all the fish!");
				exit(0);
			default:
				writefln("Error: Unknown token, 0x%x, found at token number %d", mem[i].opcode, i);
				exit(1);
				break;
		}
	}
}

void run(string filename)
{
	string fileExt = std.path.extension(filename);
	if(fileExt == ".gl")
	{
		auto text = read(filename); /* Reading in the entire file */
		decode(cast(string)text);
		execute();
	}
	else
	{
		exit(1);
	}
}
