package com.codegym.jira.ref;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.codegym.jira.common.to.TitleTo;
import com.codegym.jira.common.util.Util;
import jakarta.validation.constraints.NotNull;
import lombok.EqualsAndHashCode;
import lombok.Value;
import org.springframework.lang.Nullable;

@Value
@EqualsAndHashCode(of = "refType", callSuper = true)
public class RefTo extends TitleTo {
    @NotNull
    RefType refType;
    @Nullable
    String aux;
    @JsonIgnore
    private String[] splittedAux;

    public RefTo(Long id, RefType refType, String code, String title, @Nullable String aux) {
        super(id, code, title);
        this.refType = refType;
        this.aux = aux;
        this.splittedAux = (aux != null && aux.contains("|")) ? aux.split("\\|") : new String[0];
    }

    @JsonIgnore
    public String getAux(int idx) {
        return splittedAux.length <= idx ? null : splittedAux[idx];
    }

    @JsonIgnore
    public long getLongFromAux() {
        return Long.parseLong(Util.notNull(aux, "MAIL_NOTIFICATION {0} has no aux(mask)", this));
    }
}
