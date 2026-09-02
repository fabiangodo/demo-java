package com.rojas.holamundo;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import java.util.Map;

@RestController
@RequestMapping("/api")
public class HelloController {

    @GetMapping("/hello")
    @PreAuthorize("hasRole('OT.Read')") // <--- Cambiado de SCOPE_ a hasRole
    public Map<String, String> hello() {
        return Map.of("message", "Hello, World!");
    }
}