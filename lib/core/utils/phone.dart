/// Splits a contact's number into calling code + national number
/// (helpers.js `parsePhoneNumber`). Defaults to India.
({String code, String number}) parsePhone(String? raw) {
  if (raw == null || raw.isEmpty) return (code: '91', number: '');
  final cleaned = raw.replaceAll(RegExp(r'[^\d+]'), '');
  final digits = cleaned.replaceAll(RegExp(r'\D'), '');
  const three = [
    '971',
    '966',
    '974',
    '973',
    '965',
    '968',
    '960',
    '961',
    '962',
    '963',
    '964',
    '967',
    '970',
    '972',
    '975',
    '976',
    '977',
    '992',
    '993',
    '994',
    '995',
    '996',
    '998',
  ];
  const two = [
    '91',
    '44',
    '86',
    '81',
    '82',
    '65',
    '60',
    '61',
    '62',
    '63',
    '64',
    '66',
    '84',
    '90',
    '92',
    '93',
    '94',
    '95',
    '98',
    '20',
    '27',
    '30',
    '31',
    '32',
    '33',
    '34',
    '36',
    '39',
    '40',
    '41',
    '43',
    '45',
    '46',
    '47',
    '48',
    '49',
    '51',
    '52',
    '53',
    '54',
    '55',
    '56',
    '57',
    '58',
  ];
  if (cleaned.startsWith('+')) {
    for (final c in [...three, ...two]) {
      if (digits.startsWith(c) && digits.length > c.length) return (code: c, number: digits.substring(c.length));
    }
    if (digits.startsWith('1') && digits.length > 1) return (code: '1', number: digits.substring(1));
  }
  if (digits.startsWith('91') && digits.length >= 12) return (code: '91', number: digits.substring(2));
  for (final c in ['971', '966']) {
    if (digits.startsWith(c) && digits.length >= 12) return (code: c, number: digits.substring(3));
  }
  for (final c in ['974', '973', '965', '968']) {
    if (digits.startsWith(c) && digits.length >= 11) return (code: c, number: digits.substring(3));
  }
  if (digits.startsWith('0') && digits.length == 11) return (code: '91', number: digits.substring(1));
  return (code: '91', number: digits);
}
