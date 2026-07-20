final _email = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

bool isValidEmail(String value) => _email.hasMatch(value.trim());

// the backend rejects anything shorter, so catch it before the round trip
bool isValidPassword(String value) => value.length >= 8;
