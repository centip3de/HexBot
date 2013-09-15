module registers;

import std.stdio;
import std.string;
import std.file;
import std.path : extension;
import std.c.stdlib;
import std.array;
import std.conv;
import cpu;

struct register 
{
	string cData = null;
	int nData;
}

alias to!(string) toString;

int toReg(int data)
{
	return data - 0xF0;
}

int toInt(string data)
{
	return to!int(strtoul(toStringz(data), null, 10));
}

const int REG = 10;
register reg[REG];
register PC;

void displayReg()
{
	for(int i = 0; i < 10; i++)
	{
		if(reg[i].nData == 0)
		{
			writeln("REG " ~ toString(i) ~ ": " ~ reg[i].cData);
		}
		else
		{
			writeln("REG " ~ toString(i) ~ ": " ~ toString(reg[i].nData)); 
		}
	}
}

void setReg(int regNum, string data)
{
	if(!isRegister(regNum))
	{
		writefln("Error: %d is not a valid register number.", regNum);
		exit(1);
	}
	regNum = toReg(regNum);
	reg[regNum].nData = 0; /* Clearing out the numerical side of the register */
	reg[regNum].cData = data; /* Assigning the string */
}

void setReg(int regNum, int data)
{
	if(!isRegister(regNum))
	{
		writefln("Error: %d is not a valid register number.", regNum);
		exit(1);
	}
	regNum = toReg(regNum);
	reg[regNum].cData = "";
	reg[regNum].nData = data;
}

string getData(int regNum)
{
	if(!isRegister(regNum))
	{
		writefln("Error: %d is not a valid register number.", regNum);
		exit(1);
	}

	regNum = toReg(regNum);
	if(reg[regNum].nData == 0)
	{ 
		return reg[regNum].cData;
	} 
	return toString(reg[regNum].nData);
}

bool isRegEmpty(int regNum)
{
	if(isRegister(regNum))
	{
		if(reg[regNum].nData == 0 && reg[regNum].cData == null)
		{
			return true;
		}
	}
	else
	{
		writefln("Error: %d is not a valid register number.", regNum);
		exit(1);
	}
	return false;
}

bool isRegister(int regNum)
{
	return regNum >= REG0 && regNum <= REG9;
}
