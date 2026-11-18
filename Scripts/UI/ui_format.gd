class_name UiFormat
extends RefCounted
## Formattazione numeri in inglese, indipendente dalla lingua del sistema (1,234 e non 1.234 / 1'234).


static func number(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return "-" + out if value < 0 else out


static func multiplier(value: float) -> String:
	return "%.2f" % value
