package com.litten.web;

import org.springframework.core.io.ClassPathResource;
import org.springframework.core.io.Resource;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.util.StreamUtils;

import java.io.IOException;
import java.nio.charset.StandardCharsets;

@RestController
public class HomeController {

    @GetMapping(value = {"/", "/index.html"}, produces = MediaType.TEXT_HTML_VALUE)
    public String index() throws IOException {
        Resource resource = new ClassPathResource("static/index.html");
        if (!resource.exists()) {
            return "<!DOCTYPE html><html><body><h1>File not found: index.html</h1></body></html>";
        }
        return StreamUtils.copyToString(resource.getInputStream(), StandardCharsets.UTF_8);
    }

    @GetMapping(value = "/note.html", produces = MediaType.TEXT_HTML_VALUE)
    public String note() throws IOException {
        Resource resource = new ClassPathResource("static/note.html");
        if (!resource.exists()) {
            return "<!DOCTYPE html><html><body><h1>File not found: note.html</h1></body></html>";
        }
        return StreamUtils.copyToString(resource.getInputStream(), StandardCharsets.UTF_8);
    }

    @GetMapping("/test")
    public String test() {
        return "Server is running!";
    }
}
