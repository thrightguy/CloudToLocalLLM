## Email Server Authentication (SPF, DKIM, DMARC)

This section outlines the steps taken to configure SPF, DKIM, and DMARC for the domain `cloudtolocalllm.online` to ensure proper email authentication and improve deliverability from the VPS. The mail server hostname is `mail.cloudtolocalllm.online` (IP: `162.254.34.115`).

### 1. Install Required Packages (on VPS)

-   **OpenDKIM & Tools:**
    ```bash
    sudo dnf install -y opendkim opendkim-tools
    ```
-   **Postfix:** (Ensure it's installed)
    ```bash
    sudo dnf install -y postfix
    ```
-   **Mail Sending Utility (s-nail):**
    ```bash
    sudo dnf install -y s-nail
    ```
-   **DNS Utilities (for testing):**
    ```bash
    sudo dnf install -y bind-utils
    ```

### 2. Configure OpenDKIM

-   **Create Key Directory:**
    ```bash
    sudo mkdir -p /etc/opendkim/keys/cloudtolocalllm.online
    cd /etc/opendkim/keys/cloudtolocalllm.online
    ```
-   **Generate DKIM Keys:**
    ```bash
    sudo opendkim-genkey -s default -d cloudtolocalllm.online
    sudo chown opendkim:opendkim default.private
    sudo chmod 600 default.private
    ```
    (This creates `default.private` and `default.txt`)

-   **Configure `/etc/opendkim.conf`:**
    The file was updated to include:
    ```
    PidFile /run/opendkim/opendkim.pid
    Mode sv
    Syslog yes
    SyslogSuccess yes
    LogWhy yes
    UserID opendkim:opendkim
    Socket local:/run/opendkim/opendkim.sock # Ensure this matches Postfix config
    Umask 002
    SendReports yes
    SoftwareHeader yes
    Canonicalization relaxed/relaxed
    Domain cloudtolocalllm.online
    Selector default
    MinimumKeyBits 1024
    KeyTable refile:/etc/opendkim/KeyTable
    SigningTable refile:/etc/opendkim/SigningTable
    ExternalIgnoreList refile:/etc/opendkim/TrustedHosts
    InternalHosts refile:/etc/opendkim/TrustedHosts
    OversignHeaders From
    ```

-   **Create `/etc/opendkim/KeyTable`:**
    ```
    default._domainkey.cloudtolocalllm.online cloudtolocalllm.online:default:/etc/opendkim/keys/cloudtolocalllm.online/default.private
    ```

-   **Create `/etc/opendkim/SigningTable`:**
    ```
    *@cloudtolocalllm.online default._domainkey.cloudtolocalllm.online
    ```

-   **Create `/etc/opendkim/TrustedHosts`:**
    ```
    127.0.0.1
    localhost
    *.cloudtolocalllm.online
    mail.cloudtolocalllm.online # Added for explicitness
    ```

-   **Set Permissions:**
    ```bash
    sudo chown -R opendkim:opendkim /etc/opendkim
    sudo chmod -R go-rwx /etc/opendkim/keys
    ```

### 3. Configure Postfix

-   **Set Hostname & HELO Name:**
    In `/etc/postfix/main.cf` (or using `postconf`):
    ```
    myhostname = mail.cloudtolocalllm.online
    smtp_helo_name = $myhostname
    ```
-   **Configure Milter (OpenDKIM integration):**
    Add to `/etc/postfix/main.cf`:
    ```
    # Milter configuration (OpenDKIM)
    milter_default_action = accept
    milter_protocol = 6
    smtpd_milters = local:/run/opendkim/opendkim.sock
    non_smtpd_milters = local:/run/opendkim/opendkim.sock
    ```
-   **Allow Postfix to access OpenDKIM socket:**
    ```bash
    sudo usermod -a -G opendkim postfix
    ```
-   **Ensure Postfix listens on all interfaces:**
    In `/etc/postfix/main.cf` (or using `postconf`):
    ```
    inet_interfaces = all
    ```

### 4. Configure OS Hostname
    ```bash
    sudo hostnamectl set-hostname mail.cloudtolocalllm.online
    ```

### 5. Start/Enable Services
    ```bash
    sudo systemctl enable opendkim
    sudo systemctl start opendkim
    sudo systemctl restart postfix
    ```

### 6. DNS Records (Managed via Namecheap)

-   **A Record for Mail Server:**
    -   Type: `A`
    -   Host: `mail`
    -   Value: `162.254.34.115`

-   **PTR Record (Reverse DNS):**
    -   Configured via VPS provider for IP `162.254.34.115` to point to `mail.cloudtolocalllm.online`.

-   **SPF Record:**
    -   Type: `TXT`
    -   Host: `@`
    -   Value: `v=spf1 a:mail.cloudtolocalllm.online ip4:162.254.34.115 ~all`

-   **DKIM Public Key Record:**
    -   Type: `TXT`
    -   Host: `default._domainkey`
    -   Value: (Content from `/etc/opendkim/keys/cloudtolocalllm.online/default.txt`)
      `v=DKIM1; k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDbP9zD2UfIrytibXldih70MULwpXohGYdo9/ZV5reeouudAb7HX/lmFp22VWeR/yRQQc0cTAApsObksM/zPE3GrOl9iSXKfPWzgT/0aEi2s166AbyqchC4RZ2rVAfHwFjU04F+oWV6801V3Np5+NS9klK1NEcvZEYn2AlOo7RvUQIDAQAB`

-   **DMARC Record:**
    -   Type: `TXT`
    -   Host: `_dmarc`
    -   Value: `v=DMARC1; p=none; rua=mailto:dmarc-reports@cloudtolocalllm.online; ruf=mailto:dmarc-reports@cloudtolocalllm.online; fo=1; adkim=r; aspf=r`
    (Ensure `dmarc-reports@cloudtolocalllm.online` is a valid alias/mailbox, e.g., aliased to `cloudllm` in `/etc/aliases`)

### 7. Testing

-   Used `learndmarc.com` by sending an email to a unique address provided by the service.
-   Final test results confirmed SPF, DKIM, and DMARC PASS with proper alignment.

![DMARC, SPF, and DKIM passing results from learndmarc.com](images/mail-dkim-dmark-valid.png) 