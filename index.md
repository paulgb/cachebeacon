# Piggybacking common web beacons to track users maliciously

Most technical users know that when they access the internet over an untrusted connection, any data sent unencrypted can be intercepted by the router. However, it is generally assumed that the risk subsides when the connection ends. This is not the case. As I will demonstrate, by piggybacking malicious code on common web “beacons” and tracking codes, it is possible for a malicious router to run arbitrary Javascript code on any page which uses one of the piggybacked beacons. These beacons include Google Analytics and Facebook Connect.

Demo Video
----------

In this video I demonstrate this attack in a controlled environment.

<iframe width="560" height="315" src="http://www.youtube.com/embed/_BUg9NzdLd4" frameborder="0" allowfullscreen></iframe>

How it Works
------------

A user connects to a malicious network. The network’s DNS server is controlled by the attacker. Every time the user makes a DNS request, the DNS server responds with the IP of an HTTP proxy server controlled by the attacker. The proxy server allows the attacker to modify the responses made by the user.

When the user requests an HTML page, the proxy detects this based on the response’s `Content-Type` header and returns the original page with an invisible modification: the page references a number of predetermined javascript files in `<img>` tags. This forces the browser to make additional HTTP requests for each of these files. `<img>` is used rather than `<script>` so that the code does not run immediately but is cached to run later.

When the user requests a JavaScript file, the proxy appends additional malicious JavaScript code to the response. Additionally, the proxy server sets the response headers such that the content of these scripts is cached until a date far in the future.

When the user disconnects from the malicious network, the malicious JavaScript code stays cached in her browser. Because of the widespread use of these beacons, as she uses the web the malicious code will be loaded from the cache and inserted into most pages she visits.

Threat Analysis
---------------

This attack effectively allows the attacker to run arbitrary javascript code in a user’s browser on a large fraction of requests *even after the user has left the attacker’s network*. All that the attacker requires is that the victim connect to their network and load one HTML page over HTTP. The attacker does not have to be a rogue administrator of a popular hotspot; he can merely spoof the SSID of a popular network near a coffee shop or airport in order to have access to scores of victims.

I have identified a number of popular websites for which this attack has proven to be effective at skimming customer credit-card information. Several vendors have been contacted and are working on fixes. Strict application of the Payment Card Industry Data Security Standard will nullify this attack. In particular, using HTTPS to transfer the credit card information is not sufficient; HTTPS must appear in the URL displayed by the browser (as per PCI-DSS 4.1.e)

Impact Reduction
----------------

While the widespread use of CDNs and tracking beacons makes this attack highly pervasive, in principle the attack can be used to target any site that is loaded over HTTP. I do not suggest indiscriminately serving all content in HTTPS because of this threat, but this type of attack should be taken into consideration when deciding between HTTP and HTTPS.

Although the attack described involves a custom DNS server, DNS control is not required for this attack to work. The request rewriting could be done by intercepting the individual packets. DNS is merely a convenient way to demonstrate it since even the most basic routers allow DNS server configuration without installing custom firmware.

### Recommendations

**Users**:

- Do not use untrusted WiFi networks
- Clear cache after disconnecting from an untrusted network
- Do not enter sensitive information over a site that did not load over HTTPS, even if it claims that data will be sent securely and has a GIF of a padlock

**Vendors**:

- For all pages that display or touch sensitive data, make sure HTTPS is used for **every** page element (including the HTML page itself)
- Do not include any more external JavaScript than you need


