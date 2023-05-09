{
    "version": "1.0.0",
    "anyOf": [
        {
            "authority": "${MAA_ENDPOINT}",
            "allOf": [
                {
                    "claim": "x-ms-isolation-tee.x-ms-attestation-type",
                    "equals": "sevsnpvm"
                },
                {
                    "claim": "x-ms-isolation-tee.x-ms-compliance-status",
                    "equals": "azure-compliant-cvm"
                }
            ]
        }
    ]
}
