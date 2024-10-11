package main

import (
	"fmt"
	"log"
	"net/http"
	"net/http/httputil"
	"net/url"
	"strings"
  "strconv"
)

func getSubdomainAndPort(host string) (string, string, error) {
    // Split the host into parts
    parts := strings.Split(host, ".")
    if len(parts) < 2 {
        return "", "", fmt.Errorf("Invalid host: %s", host)
    }

    // The subdomain is always the first part
    subdomain := parts[0]

    // Default port
    port := "80"

    // Split the subdomain by '-'
    subdomainParts := strings.Split(subdomain, "-")

    // If there's more than one part after splitting by '-'
    if len(subdomainParts) > 1 {
        // Check if the last part is a valid port number
        lastPart := subdomainParts[len(subdomainParts)-1]
        if portNum, err := strconv.Atoi(lastPart); err == nil && portNum > 0 && portNum < 65536 {
            // It's a valid port number
            port = lastPart
            // Reconstruct the subdomain without the port
            subdomain = strings.Join(subdomainParts[:len(subdomainParts)-1], "-")
        }
    }

    log.Printf("Parts: %v\nHost: %s", parts, host)
    log.Printf("Subdomain: %s, Port: %s, Subdomain Parts: %v", subdomain, port, subdomainParts)

    return subdomain, port, nil
}

func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		log.Printf("Received request: %s %s", r.Method, r.URL.Path)

		host := r.Host

		// Handle default case (no subdomain)
		if !strings.Contains(host, ".") || host == "localhost" || strings.HasPrefix(host, "127.0") || strings.HasPrefix(host, "192.168.") {
			log.Printf("Handling default case for host: %s", host)
			fmt.Fprint(w, "Proxy Server Running")
			return
		}

		serviceName, port, err := getSubdomainAndPort(host)
		if err != nil {
			log.Printf("Error getting subdomain and port: %v", err)
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		log.Printf("Service: %s, Port: %s, Path: %s", serviceName, port, r.URL.Path)

		targetURL, err := url.Parse(fmt.Sprintf("http://%s-service.default.svc.cluster.local:%s", serviceName, port))
		if err != nil {
			log.Printf("Error parsing URL: %v", err)
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		log.Printf("Proxying to: %s", targetURL)

		proxy := httputil.NewSingleHostReverseProxy(targetURL)
		r.URL.Host = targetURL.Host
		r.URL.Scheme = targetURL.Scheme
		r.Header.Set("X-Forwarded-Host", r.Host)
		r.Host = targetURL.Host

		proxy.ServeHTTP(w, r)

		log.Printf("Proxied request to %s:%s%s\n", serviceName, port, r.URL.Path)
	})

	fmt.Println("Starting reverse proxy on :8000")
	if err := http.ListenAndServe(":8000", nil); err != nil {
		log.Fatal(err)
	}
}
