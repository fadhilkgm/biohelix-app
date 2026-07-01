# WhatsApp OTP — Meta Cloud API

## Credentials

| Key | Value |
|---|---|
| `WHATSAPP_ACCESS_TOKEN` | `EAAT4xbq4kzYBRdZBZC2AS3itfjW73khJtnQxPB5DDkBGm7NOqYHW5pZBzoP3ziRHT7BRX2ZAe7dESPLdAM5CtIGwJLOcoDbxYn6ZChE1fx8PIw4TZA439HOP7lEyhJZAO4q2CX4Wh0SwJldv2m30rlARmkXYhMC5zFwIZCa8zbb0M0jMq1qX70CJijtUJ0SerHkeAwZDZD` |
| `WHATSAPP_PHONE_NUMBER_ID` | `893597113830876` |
| `WHATSAPP_TEMPLATE_NAME` | `otp_login` |
| `WHATSAPP_TEMPLATE_LANGUAGE_CODE` | `en_US` |

---

## Send OTP — API Call

```
POST https://graph.facebook.com/v19.0/893597113830876/messages
Authorization: Bearer EAAT4xbq4kzYBRdZBZC2AS3itfjW73khJtnQxPB5DDkBGm7NOqYHW5pZBzoP3ziRHT7BRX2ZAe7dESPLdAM5CtIGwJLOcoDbxYn6ZChE1fx8PIw4TZA439HOP7lEyhJZAO4q2CX4Wh0SwJldv2m30rlARmkXYhMC5zFwIZCa8zbb0M0jMq1qX70CJijtUJ0SerHkeAwZDZD
Content-Type: application/json
```

```json
{
  "messaging_product": "whatsapp",
  "to": "919876543210",
  "type": "template",
  "template": {
    "name": "otp_login",
    "language": { "code": "en_US" },
    "components": [
      {
        "type": "body",
        "parameters": [{ "type": "text", "text": "123456" }]
      },
      {
        "type": "button",
        "sub_type": "url",
        "index": "0",
        "parameters": [{ "type": "text", "text": "123456" }]
      }
    ]
  }
}
```

> Replace `919876543210` with the recipient's number (country code + digits, no `+` or spaces).
> Replace `123456` in both places with your actual OTP.

---

## Node.js Code

```js
const https = require('https');

const ACCESS_TOKEN = 'EAAT4xbq4kzYBRdZBZC2AS3itfjW73khJtnQxPB5DDkBGm7NOqYHW5pZBzoP3ziRHT7BRX2ZAe7dESPLdAM5CtIGwJLOcoDbxYn6ZChE1fx8PIw4TZA439HOP7lEyhJZAO4q2CX4Wh0SwJldv2m30rlARmkXYhMC5zFwIZCa8zbb0M0jMq1qX70CJijtUJ0SerHkeAwZDZD';
const PHONE_NUMBER_ID = '893597113830876';

function sendWhatsappOTP(toPhone, otp) {
  const body = JSON.stringify({
    messaging_product: 'whatsapp',
    to: toPhone,
    type: 'template',
    template: {
      name: 'otp_login',
      language: { code: 'en_US' },
      components: [
        {
          type: 'body',
          parameters: [{ type: 'text', text: otp }],
        },
        {
          type: 'button',
          sub_type: 'url',
          index: '0',
          parameters: [{ type: 'text', text: otp }],
        },
      ],
    },
  });

  return new Promise((resolve, reject) => {
    const req = https.request(
      {
        hostname: 'graph.facebook.com',
        path: `/v19.0/${PHONE_NUMBER_ID}/messages`,
        method: 'POST',
        headers: {
          Authorization: `Bearer ${ACCESS_TOKEN}`,
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(body),
        },
      },
      (res) => {
        let data = '';
        res.on('data', (chunk) => (data += chunk));
        res.on('end', () => resolve(JSON.parse(data)));
      },
    );
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

// Usage
sendWhatsappOTP('919876543210', '123456')
  .then(console.log)
  .catch(console.error);
```

---

## Notes

- **Phone format:** digits only with country code — `919876543210` (India: `91` + 10-digit number)
- **Access token:** this is a temporary token — for production generate a permanent system user token from Meta Business Manager → System Users
- **Test numbers:** in test mode, you can only send to numbers added under WhatsApp > API Setup > "To" in the Meta dashboard
- **Template approval:** `otp_login` template must be approved in Meta Business Manager before it works on real numbers
