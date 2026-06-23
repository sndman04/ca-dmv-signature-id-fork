# Upstream Tracking

## Reference Target

Initial parity target:

```text
03c5485513ff6f2de6b46950a159b8f2cd427859
```

Reference checkout:

```text
References/cadmv-dlid-verifier-sdk/
```

## Update Process

1. Fetch the latest official SDK.
2. Record the new upstream commit hash.
3. Review changes to:
   - CBOR-LD registry tables.
   - AAMVA canonicalization.
   - DMV issuer, DID, verification method, and status-list hosts.
   - Cryptosuite behavior.
   - Status-list behavior.
   - Public sample fixtures.
4. Run the JS SDK reference tests.
5. Run the local reference runner:

   ```sh
   PATH="/Users/dougalvey/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin:$PATH" node Tools/reference-runner.mjs
   ```

6. Run `swift run CADMVVerifierSelfTest`.
7. Update this repo's Swift behavior only when parity differences are understood.
8. Update `NOTICE` if attribution or license text changes.

## Known Upstream Harness Notes

- The captured SDK commit imports `@digitalbazaar/did-io` without declaring it.
- After adding `@digitalbazaar/did-io@2.2.0`, upstream tests run with one status-check failure.
- The UAT status URL derived from the valid fixture redirects to `status.uat-credentials.dmv.ca.gov` and currently returns 404 after following the redirect.
