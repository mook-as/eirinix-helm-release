package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"os"
)

type configStruct struct {
	EnableCFAuth   bool   `json:"enable_cf_auth"`
	CcApiUrl       string `json:"cc_api_url"`
	SkipCertVerify bool   `json:"skip_cert_verify"`
	UAAUsername    string `json:"uaa_username"`
	UAAPassword    string `json:"uaa_password"`
	UAATokenURL    string `json:"uaa_token_url"`
	Address        string `json:"address"`
	LogLevel       string `json:"log_level"`
	HostKey        string `json:"host_key"`
	UAACACert      string `json:"uaa_ca_cert"`
	CCAPICACert    string `json:"cc_api_ca_cert"`
}

func writeConfig() error {
	uaaPassword, err := ioutil.ReadFile("/run/secrets/uaa-client-password")
	if err != nil {
		return fmt.Errorf("could not read UAA client password: %v", err)
	}
	hostKey, err := ioutil.ReadFile("/run/secrets/ssh-proxy-host-key.key")
	if err != nil {
		return fmt.Errorf("could not read SSH host key: %v", err)
	}
	config := configStruct{
		EnableCFAuth:   true,
		CcApiUrl:       "https://cloud-controller-ng.service.cf.internal:9024",
		SkipCertVerify: false,
		UAAUsername:    "ssh-proxy",
		UAAPassword:    string(uaaPassword),
		UAATokenURL:    "https://uaa.service.cf.internal:8443/oauth/token",
		Address:        "0.0.0.0:2222",
		LogLevel:       "info",
		HostKey:        string(hostKey),
		UAACACert:      "/run/secrets/uaa-ca.crt",
		CCAPICACert:    "/run/secrets/cc-api-ca.crt",
	}

	output, err := os.Create("/run/secrets/config/eirini-ssh-proxy.json")
	if err != nil {
		return fmt.Errorf("could not write config: %v", err)
	}
	err = json.NewEncoder(output).Encode(config)
	if err != nil {
		return fmt.Errorf("could not encode config: %v", err)
	}
	err = output.Close()
	if err != nil {
		return fmt.Errorf("could not close config: %v", err)
	}
	return nil
}
func main() {
	err := writeConfig()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error writing configuration: %v\n", err)
		os.Exit(1)
	}
}
