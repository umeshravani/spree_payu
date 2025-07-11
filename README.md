Spree PayU
====================

PayU payment system for Spree (5.1)

Install
=======

Add to your Gemfile:

    gem 'spree_payu'

and run

    bundle install

PayU India Settings
========

You'll have to set the following parameters in the Spree Admin panel (Configuration → Payment Methods → Edit PayU):
  * PayU Client (Key) — Your PayU Key (e.g., 72xxxC)
  * PayU Client Secret (Salt) — Your PayU Salt (e.g., DDEB7xxxxxxxxxxGRQEdoInLaSfFiyCj)
  * Test PayU Client (Test Key) — Your Test PayU Key (e.g., QRxxx1)
  * Test PayU Client Secret (Test Salt) — Your Test PayU Salt (e.g., 7gpOhxxxxxxxxxxnp4CkEsP0ogcIW4lh)
  * test_mode — Check this for sandbox/testing

Other fields (Return URL, Return Status URL, Max Payment Amount, Min Payment Amount, Payment Method Type, Delivery Method ID's, Image Url) are NOT required for PayU to work and can be left as default.

In Spree Admin zone you have to Select PayU and Drag it towards Top to make it default payment method.
I recommend to test it first - just select *test mode* in payment method settings and it will use the sandbox platform (https://test.payu.in/_payment) instead of production (https://secure.payu.in/_payment).

Refer to the official PayU India documentation: https://developer.payu.in/docs
