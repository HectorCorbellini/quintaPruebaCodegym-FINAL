package com.codegym.jira.login.internal.web;

import com.codegym.jira.login.User;
import com.codegym.jira.login.internal.UserRepository;
import com.codegym.jira.login.internal.passwordreset.PasswordResetEvent;
import com.codegym.jira.login.internal.passwordreset.ResetData;
import com.codegym.jira.common.error.DataConflictException;
import com.codegym.jira.common.internal.config.SecurityConfig;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpSession;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Controller;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.bind.support.SessionStatus;

@Slf4j
@Controller
@RequestMapping(PasswordController.PASSWORD_URL)
@RequiredArgsConstructor
public class PasswordController {
    static final String PASSWORD_URL = "/ui/password";
    private static final String TOKEN_ATTR = "token";
    private final UserRepository userRepository;
    private final ApplicationEventPublisher eventPublisher;

    @PostMapping("/reset")
    public String resetPassword(@RequestParam String email, HttpServletRequest request) {
        log.info("reset password {}", email);
        User user = userRepository.getExistedByEmail(email);
        ResetData resetData = new ResetData(email);
        request.getSession().setAttribute(TOKEN_ATTR, resetData);
        eventPublisher.publishEvent(new PasswordResetEvent(user, resetData.getToken()));
        return "redirect:/view/login";
    }

    @GetMapping("/change")
    public String changePassword(@RequestParam String token, Model model,
                                 @SessionAttribute(name = TOKEN_ATTR) ResetData resetData) {
        log.info("change password {}", resetData);
        if (token.equals(resetData.getToken())) {
            model.addAttribute(TOKEN_ATTR, token);
            return "/unauth/change-password";
        }
        throw new DataConflictException("Token mismatch error");
    }

    @Transactional
    @PostMapping("/save")
    @CacheEvict(value = "users", key = "#resetData.email")
    public String savePassword(@RequestParam String token, @RequestParam String password,
                               @SessionAttribute(name = TOKEN_ATTR) ResetData resetData,
                               SessionStatus status, HttpSession session) {
        log.info("save password {}", resetData);
        if (token.equals(resetData.getToken())) {
            User user = userRepository.getExistedByEmail(resetData.getEmail());
            String encodedPassword = SecurityConfig.PASSWORD_ENCODER.encode(password);
            user.setPassword(encodedPassword);
            session.invalidate();
            status.setComplete();
        }
        return "redirect:/view/login";
    }
}
